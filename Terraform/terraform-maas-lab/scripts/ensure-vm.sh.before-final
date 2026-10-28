#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 5 ]]; then
    echo "Usage: $0 <VM_NAME> <MEMORY_MB> <CPUS> <DISK_GB> <VLAN_ID>" >&2
    exit 2
fi

VM_NAME="$1"
MEMORY_MB="$2"
CPUS="$3"
DISK_GB="$4"
VLAN_ID="$5"

PXE_NET="vboxnet1"
WORKLOAD_BRIDGE="br-vlan${VLAN_ID}"

echo "========================================"
echo "Ensuring VirtualBox VM: $VM_NAME"
echo "Memory      : ${MEMORY_MB} MB"
echo "CPU         : ${CPUS}"
echo "Disk        : ${DISK_GB} GB"
echo "NIC1        : NAT"
echo "NIC2        : ${WORKLOAD_BRIDGE}"
echo "NIC3        : ${PXE_NET}"
echo "========================================"

if ! VBoxManage showvminfo "$VM_NAME" >/dev/null 2>&1; then
    echo "ERROR: VM $VM_NAME does not exist." >&2
    exit 1
fi

STATE="$(
    VBoxManage showvminfo "$VM_NAME" --machinereadable |
    awk -F= '/^VMState=/{gsub(/"/,"",$2); print $2}'
)"

echo "Current VM state: $STATE"

if [[ "$STATE" != "poweroff" ]]; then
    echo "ERROR: VM $VM_NAME must be powered off before hardware changes." >&2
    exit 1
fi

if ! ip link show "$WORKLOAD_BRIDGE" >/dev/null 2>&1; then
    echo "ERROR: $WORKLOAD_BRIDGE does not exist." >&2
    exit 1
fi

INFO="$(VBoxManage showvminfo "$VM_NAME" --machinereadable)"

OLD_MAC1="$(awk -F= '/^macaddress1=/{gsub(/"/,"",$2); print $2}' <<<"$INFO")"
OLD_MAC2="$(awk -F= '/^macaddress2=/{gsub(/"/,"",$2); print $2}' <<<"$INFO")"
OLD_MAC3="$(awk -F= '/^macaddress3=/{gsub(/"/,"",$2); print $2}' <<<"$INFO")"

# Preserve existing workload MAC.
WORKLOAD_MAC="$OLD_MAC2"

if [[ -z "$WORKLOAD_MAC" ]]; then
    echo "ERROR: NIC2 workload MAC is missing." >&2
    exit 1
fi

# Preserve existing PXE MAC.
# Existing two-NIC machines currently have PXE on NIC1.
if [[ -n "$OLD_MAC3" ]]; then
    PXE_MAC="$OLD_MAC3"
else
    PXE_MAC="$OLD_MAC1"
fi

if [[ -z "$PXE_MAC" ]]; then
    echo "ERROR: Could not determine PXE MAC." >&2
    exit 1
fi

echo "PXE MAC      : $PXE_MAC"
echo "Workload MAC : $WORKLOAD_MAC"

echo "Configuring CPU and memory..."

VBoxManage modifyvm "$VM_NAME" \
    --memory "$MEMORY_MB" \
    --cpus "$CPUS"

echo "Configuring NIC1: NAT..."

# Let VirtualBox generate NIC1 MAC only if it does not already exist
# as a dedicated NAT NIC. Existing PXE MAC must not be reused here.
CURRENT_NIC1="$(
    awk -F= '/^nic1=/{gsub(/"/,"",$2); print $2}' <<<"$INFO"
)"

if [[ "$CURRENT_NIC1" == "nat" && -n "$OLD_MAC1" && "$OLD_MAC1" != "$PXE_MAC" ]]; then
    VBoxManage modifyvm "$VM_NAME" \
        --nic1 nat \
        --nictype1 82540EM \
        --macaddress1 "$OLD_MAC1" \
        --cableconnected1 on
else
    VBoxManage modifyvm "$VM_NAME" \
        --nic1 nat \
        --nictype1 82540EM \
        --macaddress1 auto \
        --cableconnected1 on
fi

echo "Configuring NIC2: workload VLAN ${VLAN_ID}..."

VBoxManage modifyvm "$VM_NAME" \
    --nic2 bridged \
    --bridgeadapter2 "$WORKLOAD_BRIDGE" \
    --nictype2 82540EM \
    --macaddress2 "$WORKLOAD_MAC" \
    --cableconnected2 on

echo "Configuring NIC3: MAAS/PXE..."

VBoxManage modifyvm "$VM_NAME" \
    --nic3 hostonly \
    --host-only-adapter3 "$PXE_NET" \
    --nictype3 82540EM \
    --macaddress3 "$PXE_MAC" \
    --cableconnected3 on

echo
echo "Final NIC mapping:"
VBoxManage showvminfo "$VM_NAME" --machinereadable |
grep -E '^(nic[123]|macaddress[123]|hostonlyadapter3|bridgeadapter2|cableconnected[123])='

echo
echo "VM $VM_NAME configuration is ready."
