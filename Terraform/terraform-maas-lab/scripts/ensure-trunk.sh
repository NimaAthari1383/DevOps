#!/usr/bin/env bash
set -euo pipefail

OVS_BRIDGE="br-maas"
TRUNK_BRIDGE="br-maas-trunk"
OVS_IF="ovs-trunk"
VBOX_IF="vbox-trunk"

sudo ovs-vsctl --may-exist add-br "$OVS_BRIDGE"

if ! ip link show "$TRUNK_BRIDGE" >/dev/null 2>&1; then
    sudo ip link add "$TRUNK_BRIDGE" type bridge
fi

sudo ip link set "$TRUNK_BRIDGE" up

if ! ip link show "$OVS_IF" >/dev/null 2>&1; then
    sudo ip link add "$OVS_IF" type veth peer name "$VBOX_IF"
fi

sudo ip link set "$OVS_IF" up
sudo ip link set "$VBOX_IF" up

CURRENT_MASTER="$(basename "$(readlink -f /sys/class/net/${VBOX_IF}/master 2>/dev/null)" 2>/dev/null || true)"

if [[ "$CURRENT_MASTER" != "$TRUNK_BRIDGE" ]]; then
    sudo ip link set "$VBOX_IF" nomaster 2>/dev/null || true
    sudo ip link set "$VBOX_IF" master "$TRUNK_BRIDGE"
fi

sudo ovs-vsctl --may-exist add-port "$OVS_BRIDGE" "$OVS_IF"

echo "Trunk ready:"
echo "  OVS bridge:   $OVS_BRIDGE"
echo "  VBox bridge:  $TRUNK_BRIDGE"
