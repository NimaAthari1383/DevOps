#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 7 ]]; then
    echo "Usage: $0 <VM_NAME> <MEMORY_MB> <CPUS> <DISK_GB> <VLAN_ID> <WORKLOAD_MAC> <PXE_MAC>" >&2
    exit 2
fi

VM_NAME="$1"
MEMORY_MB="$2"
CPUS="$3"
DISK_GB="$4"
VLAN_ID="$5"
WORKLOAD_MAC="$6"
PXE_MAC="$7"

PXE_NET="vboxnet1"
WORKLOAD_BRIDGE="br-vlan${VLAN_ID}"

normalize_mac() {
    echo "$1" |
        tr '[:lower:]' '[:upper:]' |
        tr -d ':-'
}

WORKLOAD_MAC="$(normalize_mac "$WORKLOAD_MAC")"
PXE_MAC="$(normalize_mac "$PXE_MAC")"

if [[ -z "$WORKLOAD_MAC" || -z "$PXE_MAC" ]]; then
    echo "ERROR: workload_mac and pxe_mac are required." >&2
    exit 1
fi

if [[ "$WORKLOAD_MAC" == "$PXE_MAC" ]]; then
    echo "ERROR: workload_mac and pxe_mac must be different." >&2
    exit 1
fi

echo "========================================"
echo "VirtualBox two-NIC node configuration"
echo "========================================"
echo "VM             : $VM_NAME"
echo "Memory         : $MEMORY_MB MB"
echo "CPUs           : $CPUS"
echo "Disk metadata  : $DISK_GB GB"
echo "Workload VLAN  : $VLAN_ID"
echo "NIC1 PXE/MGMT  : $PXE_MAC"
echo "NIC2 Workload  : $WORKLOAD_MAC"
echo

if ! VBoxManage showvminfo "$VM_NAME" >/dev/null 2>&1; then
    echo "ERROR: VM $VM_NAME does not exist." >&2
    exit 1
fi

STATE="$(
    VBoxManage showvminfo "$VM_NAME" --machinereadable |
    awk -F= '/^VMState=/{gsub(/"/,"",$2); print $2}'
)"

if [[ "$STATE" != "poweroff" ]]; then
    echo "ERROR: $VM_NAME must be powered off." >&2
    echo "Current state: $STATE" >&2
    exit 1
fi

if ! ip link show "$WORKLOAD_BRIDGE" >/dev/null 2>&1; then
    echo "ERROR: workload bridge $WORKLOAD_BRIDGE does not exist." >&2
    exit 1
fi

if ! ip link show "$PXE_NET" >/dev/null 2>&1; then
    echo "ERROR: management interface $PXE_NET does not exist." >&2
    exit 1
fi

VBoxManage modifyvm "$VM_NAME" \
    --memory "$MEMORY_MB" \
    --cpus "$CPUS"

# NIC1 = MAAS / PXE / Management
VBoxManage modifyvm "$VM_NAME" \
    --nic1 hostonly \
    --host-only-adapter1 "$PXE_NET" \
    --nictype1 82540EM \
    --macaddress1 "$PXE_MAC" \
    --cableconnected1 on

# NIC2 = Workload VLAN
VBoxManage modifyvm "$VM_NAME" \
    --nic2 bridged \
    --bridgeadapter2 "$WORKLOAD_BRIDGE" \
    --nictype2 82540EM \
    --macaddress2 "$WORKLOAD_MAC" \
    --cableconnected2 on

# Old NAT NIC is removed completely.
VBoxManage modifyvm "$VM_NAME" \
    --nic3 none

echo
echo "Final interface layout:"

VBoxManage showvminfo "$VM_NAME" --machinereadable |
grep -E \
'^(nic[123]|macaddress[12]|bridgeadapter2|hostonlyadapter1|cableconnected[12])='
