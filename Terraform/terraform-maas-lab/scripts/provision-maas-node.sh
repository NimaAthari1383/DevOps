#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 13 ]]; then
    cat >&2 <<USAGE
Usage:
$0 VM_NAME MEMORY_MB CPUS DISK_GB VLAN_ID WORKLOAD_SUBNET WORKLOAD_IP \
WORKLOAD_MAC PXE_MAC MAAS_HOST MAAS_PROFILE MAAS_FABRIC_ID MGMT_GATEWAY
USAGE
    exit 2
fi

VM_NAME="$1"
MEMORY_MB="$2"
CPUS="$3"
DISK_GB="$4"
VLAN_ID="$5"
WORKLOAD_SUBNET="$6"
WORKLOAD_IP="$7"
WORKLOAD_MAC="$8"
PXE_MAC="$9"
MAAS_HOST="${10}"
PROFILE="${11}"
FABRIC_ID="${12}"
MGMT_GATEWAY="${13}"

MGMT_SUBNET="192.168.252.0/24"
IPXE_ISO="/usr/lib/ipxe/ipxe.iso"

SCRIPT_DIR="$(
    cd "$(dirname "${BASH_SOURCE[0]}")"
    pwd
)"

ENSURE_VM_SCRIPT="${SCRIPT_DIR}/ensure-vm.sh"
AWX_SCRIPT="${SCRIPT_DIR}/trigger-awx.sh"

SSH=(
    ssh
    -o ControlMaster=no
    -o ControlPath=none
    -o ConnectTimeout=10
    root@"$MAAS_HOST"
)

log() {
    printf '\n[%s] %s\n' "$(date '+%F %T')" "$*"
}

die() {
    echo "ERROR: $*" >&2
    exit 1
}

normalize_mac() {
    local mac="$1"

    mac="$(
        echo "$mac" |
        tr '[:upper:]' '[:lower:]' |
        tr -d ':-'
    )"

    [[ ${#mac} -eq 12 ]] ||
        die "Invalid MAC address: $1"

    printf '%s:%s:%s:%s:%s:%s\n' \
        "${mac:0:2}" \
        "${mac:2:2}" \
        "${mac:4:2}" \
        "${mac:6:2}" \
        "${mac:8:2}" \
        "${mac:10:2}"
}

PXE_MAC_N="$(normalize_mac "$PXE_MAC")"
WORKLOAD_MAC_N="$(normalize_mac "$WORKLOAD_MAC")"

[[ "$PXE_MAC_N" != "$WORKLOAD_MAC_N" ]] ||
    die "PXE and workload MAC addresses must be different"

vm_state() {
    VBoxManage showvminfo "$VM_NAME" --machinereadable |
    awk -F= '
        /^VMState=/ {
            gsub(/"/, "", $2)
            print $2
        }
    '
}

start_vm_if_needed() {
    local state

    state="$(vm_state)"

    case "$state" in
        running)
            return 0
            ;;

        poweroff|saved|aborted)
            log "Starting VM $VM_NAME"
            VBoxManage startvm "$VM_NAME" --type headless
            ;;

        *)
            log "VM state is '$state'; not issuing start command"
            ;;
    esac
}

poweroff_vm() {
    local state

    state="$(vm_state)"

    if [[ "$state" == "poweroff" ]]; then
        return 0
    fi

    log "Powering off $VM_NAME"

    VBoxManage controlvm "$VM_NAME" poweroff >/dev/null 2>&1 || true

    for _ in $(seq 1 30); do
        if [[ "$(vm_state)" == "poweroff" ]]; then
            return 0
        fi
        sleep 1
    done

    die "$VM_NAME did not power off"
}

machine_json() {
    "${SSH[@]}" \
        "maas $PROFILE machine read $SYSTEM_ID"
}

machine_status() {
    machine_json |
    jq -r '.status_name'
}

lookup_machine() {
    "${SSH[@]}" \
        "maas $PROFILE machines read" |
    jq -r \
        --arg pxe "$PXE_MAC_N" \
        --arg workload "$WORKLOAD_MAC_N" '
            .[] |
            select(
                [.interface_set[]?.mac_address | ascii_downcase] as $macs |
                ($macs | index($pxe)) != null or
                ($macs | index($workload)) != null
            ) |
            .system_id
        ' |
    head -1
}

lookup_iface_id() {
    local mac="$1"

    "${SSH[@]}" \
        "maas $PROFILE interfaces read $SYSTEM_ID" |
    jq -r \
        --arg mac "$mac" '
            .[] |
            select(
                (.mac_address | ascii_downcase) == $mac
            ) |
            .id
        ' |
    head -1
}

lookup_subnet_id() {
    local cidr="$1"

    "${SSH[@]}" \
        "maas $PROFILE subnets read" |
    jq -r \
        --arg cidr "$cidr" '
            .[] |
            select(.cidr == $cidr) |
            .id
        ' |
    head -1
}

lookup_subnet_vlan_id() {
    local cidr="$1"

    "${SSH[@]}" \
        "maas $PROFILE subnets read" |
    jq -r \
        --arg cidr "$cidr" '
            .[] |
            select(.cidr == $cidr) |
            .vlan.id
        ' |
    head -1
}

lookup_subnet_gateway() {
    local cidr="$1"

    "${SSH[@]}" \
        "maas $PROFILE subnets read" |
    jq -r \
        --arg cidr "$cidr" '
            .[] |
            select(.cidr == $cidr) |
            .gateway_ip // empty
        ' |
    head -1
}

lookup_vlan_id() {
    "${SSH[@]}" \
        "maas $PROFILE vlans read $FABRIC_ID" |
    jq -r \
        --argjson vid "$VLAN_ID" '
            .[] |
            select(.vid == $vid) |
            .id
        ' |
    head -1
}

wait_status() {
    local wanted="$1"
    local timeout="${2:-1200}"
    local elapsed=0

    while (( elapsed < timeout )); do
        local status
        local state

        status="$(machine_status)"
        state="$(vm_state)"

        printf '[MAAS] status=%-24s vm=%s\n' \
            "$status" "$state"

        if [[ "$status" == "$wanted" ]]; then
            return 0
        fi

        case "$status" in
            "Failed commissioning"|"Failed testing")
                die "MAAS entered '$status'"
                ;;
        esac

        sleep 10
        elapsed=$((elapsed + 10))
    done

    die "Timeout waiting for MAAS status '$wanted'"
}

wait_enlist() {
    log "Waiting for MAAS enlistment"

    for attempt in $(seq 1 120); do
        SYSTEM_ID="$(lookup_machine || true)"

        if [[ -n "$SYSTEM_ID" ]]; then
            log "Machine found in MAAS: $SYSTEM_ID"
            return 0
        fi

        printf 'Waiting for enlistment: %d/120\n' "$attempt"
        sleep 5
    done

    die "Node did not enlist into MAAS"
}

wait_installation() {
    log "Waiting for curtin installation"

    for attempt in $(seq 1 720); do
        local status
        local install
        local state

        status="$(machine_status)"

        install="$(
            "${SSH[@]}" \
                "maas $PROFILE node-script-result read $SYSTEM_ID current-installation 2>/dev/null" |
            jq -r '.status_name // "NotStarted"' \
            2>/dev/null || true
        )"

        [[ -n "$install" ]] || install="NotStarted"

        state="$(vm_state)"

        printf '[%03d/720] MAAS=%s INSTALL=%s VM=%s\n' \
            "$attempt" "$status" "$install" "$state"

        if [[ "$status" == "Failed deployment" ]]; then
            die "MAAS deployment failed"
        fi

        if [[ "$install" == "Passed" ]]; then
            log "Curtin installation passed"
            return 0
        fi

        sleep 10
    done

    die "Timeout waiting for curtin installation"
}

wait_deployed() {
    log "Waiting for MAAS status Deployed"

    for attempt in $(seq 1 90); do
        local status
        local state

        status="$(machine_status)"
        state="$(vm_state)"

        printf '[%02d/90] MAAS=%s VM=%s\n' \
            "$attempt" "$status" "$state"

        if [[ "$status" == "Deployed" ]]; then
            return 0
        fi

        if [[ "$status" == "Failed deployment" ]]; then
            die "MAAS reports Failed deployment"
        fi

        sleep 10
    done

    die "Timeout waiting for MAAS status Deployed"
}

verify_management_subnet() {
    local subnet
    local gateway
    local dns_ok

    subnet="$(
        "${SSH[@]}" \
            "maas $PROFILE subnets read" |
        jq -c \
            --arg cidr "$MGMT_SUBNET" '
                .[] |
                select(.cidr == $cidr)
            '
    )"

    [[ -n "$subnet" ]] ||
        die "Management subnet not found: $MGMT_SUBNET"

    gateway="$(
        jq -r '.gateway_ip // empty' <<<"$subnet"
    )"

    [[ "$gateway" == "$MGMT_GATEWAY" ]] ||
        die "Management gateway is '$gateway'; expected '$MGMT_GATEWAY'"

    dns_ok="$(
        jq -r \
            --arg dns "$MAAS_HOST" '
                (.dns_servers // []) |
                index($dns) != null
            ' <<<"$subnet"
    )"

    [[ "$dns_ok" == "true" ]] ||
        die "Management subnet does not use MAAS DNS $MAAS_HOST"

    log "Management subnet verified"
    echo "  CIDR    : $MGMT_SUBNET"
    echo "  Gateway : $MGMT_GATEWAY"
    echo "  DNS     : $MAAS_HOST"
}

verify_workload_subnet() {
    local gateway
    local dns_ok

    gateway="$(lookup_subnet_gateway "$WORKLOAD_SUBNET")"

    [[ -n "$gateway" ]] ||
        die "Workload subnet $WORKLOAD_SUBNET has no gateway"

    dns_ok="$(
        "${SSH[@]}" \
            "maas $PROFILE subnets read" |
        jq -r \
            --arg cidr "$WORKLOAD_SUBNET" \
            --arg dns "$MAAS_HOST" '
                .[] |
                select(.cidr == $cidr) |
                ((.dns_servers // []) | index($dns) != null)
            '
    )"

    [[ "$dns_ok" == "true" ]] ||
        die "Workload subnet $WORKLOAD_SUBNET does not use MAAS DNS $MAAS_HOST"

    log "Workload subnet verified"
    echo "  CIDR    : $WORKLOAD_SUBNET"
    echo "  Gateway : $gateway"
    echo "  DNS     : $MAAS_HOST"
}

ensure_link() {
    local iface_id="$1"
    local cidr="$2"
    local mode="$3"
    local ip="${4:-}"

    local subnet_id
    local existing

    subnet_id="$(lookup_subnet_id "$cidr")"

    [[ -n "$subnet_id" ]] ||
        die "Subnet not found in MAAS: $cidr"

    existing="$(
        "${SSH[@]}" \
            "maas $PROFILE interface read $SYSTEM_ID $iface_id" |
        jq -r \
            --arg cidr "$cidr" '
                [
                    .links[]? |
                    select(.subnet.cidr == $cidr)
                ] |
                length
            '
    )"

    if (( existing > 0 )); then
        log "Interface $iface_id already linked to $cidr"
        return 0
    fi

    case "$mode" in
        STATIC)
            "${SSH[@]}" \
                "maas $PROFILE interface link-subnet $SYSTEM_ID $iface_id mode=STATIC subnet=$subnet_id ip_address=$ip" \
                >/dev/null
            ;;

        AUTO|DHCP)
            "${SSH[@]}" \
                "maas $PROFILE interface link-subnet $SYSTEM_ID $iface_id mode=$mode subnet=$subnet_id" \
                >/dev/null
            ;;

        *)
            die "Unsupported MAAS link mode: $mode"
            ;;
    esac
}

get_management_ip() {
    local ip

    ip="$(
        "${SSH[@]}" \
            "maas $PROFILE interface read $SYSTEM_ID $PXE_IFACE" |
        jq -r \
            --arg cidr "$MGMT_SUBNET" '
                .links[]? |
                select(.subnet.cidr == $cidr) |
                .ip_address // empty
            ' |
        head -1
    )"

    [[ -n "$ip" ]] ||
        die "Management IP not found for MAAS interface $PXE_IFACE"

    printf '%s\n' "$ip"
}

wait_ssh() {
    local ip="$1"

    log "Waiting for SSH on $ip:22"

    for attempt in $(seq 1 120); do
        if nc -z -w2 "$ip" 22 >/dev/null 2>&1; then
            log "SSH is ready on $ip:22"
            return 0
        fi

        printf 'Waiting for SSH: %d/120\n' "$attempt"
        sleep 5
    done

    die "SSH did not become ready on $ip:22"
}

[[ -f "$IPXE_ISO" ]] ||
    die "iPXE ISO missing: $IPXE_ISO"

[[ -x "$ENSURE_VM_SCRIPT" ]] ||
    die "ensure-vm.sh is missing or not executable"

[[ -x "$AWX_SCRIPT" ]] ||
    die "trigger-awx.sh is missing or not executable"

[[ -n "$WORKLOAD_IP" ]] ||
    die "workload_ip is required"

SYSTEM_ID="$(lookup_machine || true)"

# Protect already deployed nodes from automatic migration/reprovisioning.
if [[ -n "$SYSTEM_ID" ]]; then
    STATUS="$(machine_status)"

    if [[ "$STATUS" == "Deployed" ]]; then
        log "$VM_NAME is already Deployed in MAAS ($SYSTEM_ID)"

        STATE="$(vm_state)"

        if [[ "$STATE" == "poweroff" ]]; then
            log "$VM_NAME is deployed but powered off; starting it"
            VBoxManage startvm "$VM_NAME" --type headless
        else
            log "$VM_NAME runtime state: $STATE"
        fi

        log "Provisioning skipped for safety."
        exit 0
    fi
fi

verify_management_subnet
verify_workload_subnet

poweroff_vm

"$ENSURE_VM_SCRIPT" \
    "$VM_NAME" \
    "$MEMORY_MB" \
    "$CPUS" \
    "$DISK_GB" \
    "$VLAN_ID" \
    "$WORKLOAD_MAC" \
    "$PXE_MAC"

log "Attaching iPXE ISO"

VBoxManage storageattach "$VM_NAME" \
    --storagectl "IDE" \
    --port 0 \
    --device 0 \
    --type dvddrive \
    --medium "$IPXE_ISO"

log "Configuring PXE boot topology"

VBoxManage modifyvm "$VM_NAME" \
    --boot1 dvd \
    --boot2 disk \
    --boot3 none \
    --boot4 none \
    --cableconnected1 on \
    --cableconnected2 on

if [[ -z "$SYSTEM_ID" ]]; then
    log "Starting PXE enlistment"
    start_vm_if_needed
    wait_enlist
fi

STATUS="$(machine_status)"

log "MAAS system ID: $SYSTEM_ID"
log "Current MAAS state: $STATUS"

case "$STATUS" in
    New)
        log "Machine is New; configuring manual power type before acceptance"

        "${SSH[@]}" \
            "maas $PROFILE machine update $SYSTEM_ID power_type=manual" \
            >/dev/null

        log "Accepting enlisted machine into MAAS"

        "${SSH[@]}" \
            "maas $PROFILE machines accept machines=$SYSTEM_ID" \
            >/dev/null

        log "MAAS acceptance started commissioning"

        start_vm_if_needed
        wait_status "Ready" 1200
        ;;

    "Failed commissioning")
        log "Machine failed commissioning; configuring manual power and retrying"

        "${SSH[@]}" \
            "maas $PROFILE machine update $SYSTEM_ID power_type=manual" \
            >/dev/null

        "${SSH[@]}" \
            "maas $PROFILE machine commission $SYSTEM_ID skip_bmc_config=1 testing_scripts=none" \
            >/dev/null

        start_vm_if_needed
        wait_status "Ready" 1200
        ;;

    Commissioning)
        log "Machine is already commissioning"

        start_vm_if_needed
        wait_status "Ready" 1200
        ;;

    Testing)
        log "Machine is currently testing"

        start_vm_if_needed
        wait_status "Ready" 1200
        ;;

    Ready)
        log "Machine is already Ready"
        ;;

    "Failed deployment")
        die "Machine is in Failed deployment state; recover it before continuing"
        ;;

    *)
        die "Unsupported MAAS state before deployment: $STATUS"
        ;;
esac

PXE_IFACE="$(lookup_iface_id "$PXE_MAC_N")"
WORKLOAD_IFACE="$(lookup_iface_id "$WORKLOAD_MAC_N")"

[[ -n "$PXE_IFACE" ]] ||
    die "PXE interface not found for MAC $PXE_MAC_N"

[[ -n "$WORKLOAD_IFACE" ]] ||
    die "Workload interface not found for MAC $WORKLOAD_MAC_N"

log "Resolved MAAS interfaces"
echo "  PXE / management : $PXE_IFACE ($PXE_MAC_N)"
echo "  Workload         : $WORKLOAD_IFACE ($WORKLOAD_MAC_N)"

BOOT_IFACE="$(
    machine_json |
    jq -r '.boot_interface.id'
)"

[[ "$BOOT_IFACE" == "$PXE_IFACE" ]] ||
    die "Wrong MAAS boot interface. Expected $PXE_IFACE, got $BOOT_IFACE"

log "MAAS boot interface verified: $BOOT_IFACE"

verify_management_subnet
verify_workload_subnet

WORKLOAD_VLAN_ID="$(lookup_vlan_id)"
MGMT_VLAN_ID="$(lookup_subnet_vlan_id "$MGMT_SUBNET")"

[[ -n "$WORKLOAD_VLAN_ID" ]] ||
    die "MAAS workload VLAN $VLAN_ID not found in fabric $FABRIC_ID"

[[ -n "$MGMT_VLAN_ID" ]] ||
    die "MAAS management VLAN not found for $MGMT_SUBNET"

log "MAAS VLAN association"
echo "  Workload VID      : $VLAN_ID"
echo "  Workload VLAN ID  : $WORKLOAD_VLAN_ID"
echo "  Management VLAN ID: $MGMT_VLAN_ID"

"${SSH[@]}" \
    "maas $PROFILE interface update $SYSTEM_ID $WORKLOAD_IFACE vlan=$WORKLOAD_VLAN_ID" \
    >/dev/null

"${SSH[@]}" \
    "maas $PROFILE interface update $SYSTEM_ID $PXE_IFACE vlan=$MGMT_VLAN_ID" \
    >/dev/null

ensure_link \
    "$PXE_IFACE" \
    "$MGMT_SUBNET" \
    AUTO

ensure_link \
    "$WORKLOAD_IFACE" \
    "$WORKLOAD_SUBNET" \
    STATIC \
    "$WORKLOAD_IP"

WORKLOAD_LINK_ID="$(
    "${SSH[@]}" \
        "maas $PROFILE interface read $SYSTEM_ID $WORKLOAD_IFACE" |
    jq -r \
        --arg cidr "$WORKLOAD_SUBNET" '
            .links[]? |
            select(.subnet.cidr == $cidr) |
            .id
        ' |
    head -1
)"

[[ -n "$WORKLOAD_LINK_ID" ]] ||
    die "Workload link ID not found"

WORKLOAD_GATEWAY="$(lookup_subnet_gateway "$WORKLOAD_SUBNET")"

[[ -n "$WORKLOAD_GATEWAY" ]] ||
    die "Workload gateway not found"

log "Setting workload interface as IPv4 default gateway"

"${SSH[@]}" \
    "maas $PROFILE interface set-default-gateway $SYSTEM_ID $WORKLOAD_IFACE link_id=$WORKLOAD_LINK_ID" \
    >/dev/null

DEFAULT_GW="$(
    machine_json |
    jq -r '.default_gateways.ipv4.gateway_ip // empty'
)"

[[ "$DEFAULT_GW" == "$WORKLOAD_GATEWAY" ]] ||
    die "Wrong default gateway '$DEFAULT_GW'; expected '$WORKLOAD_GATEWAY'"

log "IPv4 default gateway verified: $DEFAULT_GW"

verify_management_subnet
verify_workload_subnet

log "Deploying Ubuntu Resolute / ga-26.04"

"${SSH[@]}" \
    "maas $PROFILE machine deploy $SYSTEM_ID osystem=ubuntu distro_series=resolute hwe_kernel=ga-26.04" \
    >/dev/null

start_vm_if_needed

wait_installation

log "Installation passed; waiting for MAAS/power transition"

for attempt in $(seq 1 30); do
    STATUS="$(machine_status)"
    STATE="$(vm_state)"

    printf '[%02d/30] MAAS=%s VM=%s\n' \
        "$attempt" "$STATUS" "$STATE"

    if [[ "$STATE" == "poweroff" ]]; then
        break
    fi

    if [[ "$STATUS" == "Deployed" ]]; then
        break
    fi

    sleep 5
done

poweroff_vm

log "Detaching iPXE ISO"

VBoxManage storageattach "$VM_NAME" \
    --storagectl "IDE" \
    --port 0 \
    --device 0 \
    --type dvddrive \
    --medium emptydrive

log "Booting installed OS"

VBoxManage modifyvm "$VM_NAME" \
    --boot1 disk \
    --boot2 none \
    --boot3 none \
    --boot4 none \
    --cableconnected1 on \
    --cableconnected2 on

start_vm_if_needed

wait_deployed

MGMT_IP="$(get_management_ip)"

log "Management IP discovered: $MGMT_IP"

wait_ssh "$MGMT_IP"

log "Starting AWX configuration"

"$AWX_SCRIPT" \
    "$VM_NAME" \
    "$MGMT_IP" \
    "$WORKLOAD_IP" \
    "$SYSTEM_ID"

log "AWX configuration completed successfully"

log "Final MAAS state"

machine_json |
jq '{
    system_id,
    hostname,
    status_name,
    osystem,
    distro_series,
    hwe_kernel,
    default_gateways,
    ip_addresses
}'

echo
echo "============================================================"
echo "Provisioning completed successfully"
echo "============================================================"
echo "VM                 : $VM_NAME"
echo "MAAS system ID     : $SYSTEM_ID"
echo "Management IP      : $MGMT_IP"
echo "Management gateway : $MGMT_GATEWAY"
echo "Workload IP        : $WORKLOAD_IP"
echo "Workload VLAN      : $VLAN_ID"
echo "Default gateway    : $WORKLOAD_GATEWAY"
echo "AWX                : successful"
echo "============================================================"
