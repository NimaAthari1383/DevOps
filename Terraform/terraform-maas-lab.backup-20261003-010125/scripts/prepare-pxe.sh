#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
    echo "Usage: $0 <VM_NAME>" >&2
    exit 2
fi

VM_NAME="$1"
IPXE_ISO="/usr/lib/ipxe/ipxe.iso"

echo "========================================"
echo "Preparing PXE boot for: $VM_NAME"
echo "========================================"

if ! VBoxManage showvminfo "$VM_NAME" >/dev/null 2>&1; then
    echo "ERROR: VM $VM_NAME does not exist." >&2
    exit 1
fi

if [[ ! -f "$IPXE_ISO" ]]; then
    echo "ERROR: iPXE ISO not found: $IPXE_ISO" >&2
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

echo "Attaching iPXE ISO..."

VBoxManage storageattach "$VM_NAME" \
    --storagectl "IDE" \
    --port 0 \
    --device 0 \
    --type dvddrive \
    --medium "$IPXE_ISO"

echo "Setting boot order: DVD -> Disk -> Network..."

VBoxManage modifyvm "$VM_NAME" \
    --boot1 dvd \
    --boot2 disk \
    --boot3 net \
    --boot4 none

echo "Starting $VM_NAME..."

VBoxManage startvm "$VM_NAME" --type headless

echo
echo "$VM_NAME started for PXE/iPXE boot."
