#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
    echo "Usage: $0 <VLAN_ID>" >&2
    exit 2
fi

VID="$1"

if ! [[ "$VID" =~ ^[0-9]+$ ]] || (( VID < 1 || VID > 4094 )); then
    echo "Invalid VLAN ID: $VID" >&2
    exit 1
fi

OVS_BRIDGE="br-maas"
ACCESS_BRIDGE="br-vlan${VID}"
OVS_IF="ovs-${VID}"
VBOX_IF="vbox-${VID}"

sudo ovs-vsctl --may-exist add-br "$OVS_BRIDGE"

if ! ip link show "$ACCESS_BRIDGE" >/dev/null 2>&1; then
    sudo ip link add "$ACCESS_BRIDGE" type bridge
fi

sudo ip link set "$ACCESS_BRIDGE" up

if ! ip link show "$OVS_IF" >/dev/null 2>&1; then
    sudo ip link add "$OVS_IF" type veth peer name "$VBOX_IF"
fi

sudo ip link set "$OVS_IF" up
sudo ip link set "$VBOX_IF" up

CURRENT_MASTER="$(basename "$(readlink -f /sys/class/net/${VBOX_IF}/master 2>/dev/null)" 2>/dev/null || true)"

if [[ "$CURRENT_MASTER" != "$ACCESS_BRIDGE" ]]; then
    sudo ip link set "$VBOX_IF" nomaster 2>/dev/null || true
    sudo ip link set "$VBOX_IF" master "$ACCESS_BRIDGE"
fi

sudo ovs-vsctl --may-exist add-port "$OVS_BRIDGE" "$OVS_IF"

sudo ovs-vsctl set port "$OVS_IF" \
    tag="$VID" \
    vlan_mode=access

echo "VLAN $VID ready:"
echo "  VirtualBox bridge: $ACCESS_BRIDGE"
echo "  OVS port:          $OVS_IF"
