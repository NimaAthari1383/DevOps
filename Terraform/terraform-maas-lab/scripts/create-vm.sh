#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 5 ]]; then
    echo "Usage: $0 <VM_NAME> <MEMORY_MB> <CPUS> <DISK_GB> <VM_BASE_DIR>" >&2
    exit 2
fi

VM_NAME="$1"
MEMORY_MB="$2"
CPUS="$3"
DISK_GB="$4"
VM_BASE_DIR="$5"

if VBoxManage showvminfo "$VM_NAME" >/dev/null 2>&1; then
    echo "$VM_NAME already exists; creation skipped."
    exit 0
fi

VM_DIR="${VM_BASE_DIR}/${VM_NAME}"
VDI="${VM_DIR}/${VM_NAME}.vdi"

echo "========================================"
echo "Creating VirtualBox VM"
echo "========================================"
echo "Name   : $VM_NAME"
echo "RAM    : $MEMORY_MB MB"
echo "CPU    : $CPUS"
echo "Disk   : $DISK_GB GB"
echo "Path   : $VM_DIR"
echo

mkdir -p "$VM_DIR"

VBoxManage createvm \
    --name "$VM_NAME" \
    --ostype Ubuntu_64 \
    --basefolder "$VM_BASE_DIR" \
    --register

VBoxManage modifyvm "$VM_NAME" \
    --memory "$MEMORY_MB" \
    --cpus "$CPUS" \
    --firmware bios \
    --ioapic on

VBoxManage createmedium disk \
    --filename "$VDI" \
    --size "$((DISK_GB * 1024))" \
    --format VDI

VBoxManage storagectl "$VM_NAME" \
    --name "SATA" \
    --add sata \
    --controller IntelAhci

VBoxManage storageattach "$VM_NAME" \
    --storagectl "SATA" \
    --port 0 \
    --device 0 \
    --type hdd \
    --medium "$VDI"

VBoxManage storagectl "$VM_NAME" \
    --name "IDE" \
    --add ide

echo
echo "$VM_NAME created successfully."
