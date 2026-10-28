#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
    echo "Usage: $0 <VM_NAME> <VLAN_ID>" >&2
    exit 2
fi

VM="$1"
VID="$2"
BRIDGE="br-vlan${VID}"

if ! VBoxManage showvminfo "$VM" >/dev/null 2>&1; then
    echo "VirtualBox VM does not exist: $VM" >&2
    exit 1
fi

if ! ip link show "$BRIDGE" >/dev/null 2>&1; then
    echo "Required bridge does not exist: $BRIDGE" >&2
    exit 1
fi

STATE="$(
    VBoxManage showvminfo "$VM" --machinereadable |
    sed -n 's/^VMState="\([^"]*\)"/\1/p'
)"

if [[ "$STATE" != "poweroff" ]]; then
    echo "VM $VM must be powered off before changing NIC2."
    echo "Current state: $STATE"
    exit 1
fi

VBoxManage modifyvm "$VM" \
    --nic2 bridged \
    --bridgeadapter2 "$BRIDGE" \
    --nictype2 82540EM \
    --cable-connected2 on

echo "$VM NIC2 -> VLAN $VID via $BRIDGE"
