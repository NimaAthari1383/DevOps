#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
    echo "Usage: $0 <MGMT_IP> <PXE_MAC>" >&2
    exit 2
fi

MGMT_IP="$1"
PXE_MAC="$2"

ssh \
  -o StrictHostKeyChecking=no \
  -o UserKnownHostsFile=/dev/null \
  ubuntu@"$MGMT_IP" \
  "PXE_MAC='$PXE_MAC' bash -s" <<'REMOTE'
set -euo pipefail

PXE_MAC="$(echo "$PXE_MAC" | tr '[:upper:]' '[:lower:]')"

IFACE="$(
    for path in /sys/class/net/*; do
        [[ -f "$path/address" ]] || continue

        MAC="$(cat "$path/address" | tr '[:upper:]' '[:lower:]')"

        if [[ "$MAC" == "$PXE_MAC" ]]; then
            basename "$path"
            break
        fi
    done
)"

if [[ -z "$IFACE" ]]; then
    echo "ERROR: management interface with MAC $PXE_MAC not found" >&2
    exit 1
fi

echo "Management interface: $IFACE"

sudo install -o root -g root -m 600 /dev/null \
    /etc/systemd/network/10-maas-management.network.d/50-no-default-route.conf 2>/dev/null || true

sudo mkdir -p \
    "/etc/systemd/network/10-netplan-${IFACE}.network.d"

sudo tee \
    "/etc/systemd/network/10-netplan-${IFACE}.network.d/90-management-routing.conf" \
    >/dev/null <<EOF2
[DHCPv4]
UseRoutes=false
UseDNS=false
EOF2

sudo chmod 600 \
    "/etc/systemd/network/10-netplan-${IFACE}.network.d/90-management-routing.conf"

sudo systemctl restart systemd-networkd

sleep 2

echo
echo "===== ROUTES ====="
ip -4 route

DEFAULT_COUNT="$(
    ip -4 route |
    awk '$1 == "default" {count++} END {print count+0}'
)"

if [[ "$DEFAULT_COUNT" -ne 1 ]]; then
    echo "ERROR: expected exactly one IPv4 default route; found $DEFAULT_COUNT" >&2
    exit 1
fi

DEFAULT_DEV="$(
    ip -4 route |
    awk '$1 == "default" {print $5; exit}'
)"

if [[ "$DEFAULT_DEV" != "enp0s3" ]]; then
    echo "ERROR: IPv4 default route is on $DEFAULT_DEV, expected enp0s3" >&2
    exit 1
fi

echo
echo "Routing verification passed."
REMOTE
