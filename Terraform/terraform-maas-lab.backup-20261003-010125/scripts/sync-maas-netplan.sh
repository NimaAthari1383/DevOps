#!/usr/bin/env bash
set -euo pipefail

: "${VLANS_JSON:?VLANS_JSON is required}"

MAAS_HOST="192.168.252.10"
PARENT_IF="enp0s8"
PROFILE="Athari.Nima"
FABRIC_ID="2"

TMP_FILE="$(mktemp)"

{
    echo "network:"
    echo "  version: 2"
    echo
    echo "  ethernets:"
    echo "    ${PARENT_IF}:"
    echo "      dhcp4: false"
    echo "      dhcp6: false"
    echo
    echo "  vlans:"

    echo "$VLANS_JSON" |
    jq -r 'to_entries[] | [.key, .value.rack_ip, .value.subnet] | @tsv' |
    sort -n |
    while IFS=$'\t' read -r VID RACK_IP SUBNET; do
        PREFIX="${SUBNET##*/}"

        cat <<EOF
    "${PARENT_IF}.${VID}":
      id: ${VID}
      link: ${PARENT_IF}
      addresses:
        - ${RACK_IP}/${PREFIX}
EOF
    done
} > "$TMP_FILE"

echo "Generated MAAS Netplan:"
cat "$TMP_FILE"

scp -q \
    -o ControlMaster=no \
    -o ControlPath=none \
    "$TMP_FILE" \
    root@"$MAAS_HOST":/tmp/60-maas-workload-vlans.yaml

ssh \
    -o ControlMaster=no \
    -o ControlPath=none \
    root@"$MAAS_HOST" \
    bash -s -- \
    "$PARENT_IF" \
    "$PROFILE" \
    "$FABRIC_ID" \
    "$VLANS_JSON" <<'REMOTE'

set -euo pipefail

PARENT_IF="$1"
PROFILE="$2"
FABRIC_ID="$3"
VLANS_JSON="$4"

TARGET="/etc/netplan/60-maas-workload-vlans.yaml"
NEW="/tmp/60-maas-workload-vlans.yaml"

if [[ -f "$TARGET" ]] && cmp -s "$TARGET" "$NEW"; then
    echo "MAAS Netplan already up to date."
else
    if [[ -f "$TARGET" ]]; then
        cp "$TARGET" "${TARGET}.bak"
    fi

    install -m 600 "$NEW" "$TARGET"
    rm -f "$NEW"
fi

echo "Validating Netplan..."
netplan generate

echo "Applying Netplan..."
netplan apply

echo "Reloading systemd-networkd..."
networkctl reload || true

echo "Restarting systemd-networkd..."
systemctl restart systemd-networkd

echo "Waiting for VLAN interfaces..."

for attempt in $(seq 1 20); do
    MISSING=0

    while IFS=$'\t' read -r VID RACK_IP SUBNET; do
        IFNAME="${PARENT_IF}.${VID}"

        if ! ip link show "$IFNAME" >/dev/null 2>&1; then
            echo "Waiting for $IFNAME..."
            MISSING=1
        fi
    done < <(
        echo "$VLANS_JSON" |
        jq -r 'to_entries[] | [.key, .value.rack_ip, .value.subnet] | @tsv'
    )

    if [[ "$MISSING" -eq 0 ]]; then
        echo "All VLAN interfaces are present."
        break
    fi

    if [[ "$attempt" -eq 20 ]]; then
        echo "ERROR: VLAN interfaces did not appear." >&2
        ip -br link | grep "$PARENT_IF" || true
        exit 1
    fi

    sleep 3
done

echo "Restarting MAAS..."
snap restart maas

echo "Waiting for MAAS API..."

for attempt in $(seq 1 30); do
    if maas "$PROFILE" vlans read "$FABRIC_ID" >/dev/null 2>&1; then
        echo "MAAS API is ready."
        break
    fi

    echo "Waiting for MAAS API... attempt ${attempt}/30"

    if [[ "$attempt" -eq 30 ]]; then
        echo "ERROR: MAAS API did not become ready." >&2
        exit 1
    fi

    sleep 3
done

echo "MAAS Netplan applied successfully."

REMOTE

rm -f "$TMP_FILE"
