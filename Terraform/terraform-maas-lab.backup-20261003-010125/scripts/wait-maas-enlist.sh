#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
    echo "Usage: $0 <PXE_MAC>" >&2
    exit 2
fi

PXE_MAC="$(echo "$1" | tr '[:upper:]' '[:lower:]')"

MAAS_HOST="192.168.252.10"
PROFILE="Athari.Nima"

echo "========================================"
echo "Waiting for MAAS enlist"
echo "MAC: $PXE_MAC"
echo "========================================"

for attempt in $(seq 1 60); do

    JSON="$(
        ssh \
          -o ControlMaster=no \
          -o ControlPath=none \
          root@"$MAAS_HOST" \
          "maas $PROFILE machines read"
    )"

    SYSTEM_ID="$(
        jq -r --arg mac "$PXE_MAC" '
          .[] |
          select(
            [.interface_set[].mac_address | ascii_downcase]
            | index($mac)
          ) |
          .system_id
        ' <<<"$JSON" |
        head -1
    )"

    if [[ -n "$SYSTEM_ID" ]]; then
        STATUS="$(
            jq -r --arg id "$SYSTEM_ID" '
              .[] |
              select(.system_id == $id) |
              .status_name
            ' <<<"$JSON"
        )"

        HOSTNAME="$(
            jq -r --arg id "$SYSTEM_ID" '
              .[] |
              select(.system_id == $id) |
              .hostname
            ' <<<"$JSON"
        )"

        echo
        echo "Machine found in MAAS."
        echo "System ID : $SYSTEM_ID"
        echo "Hostname  : $HOSTNAME"
        echo "Status    : $STATUS"

        exit 0
    fi

    echo "Waiting for enlist... attempt ${attempt}/60"
    sleep 5
done

echo "ERROR: Machine with MAC $PXE_MAC did not enlist after 5 minutes." >&2
exit 1
