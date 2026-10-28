#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 6 ]]; then
    echo "Usage: $0 <VID> <CIDR> <GATEWAY> <RACK_IP> <DHCP_START> <DHCP_END>" >&2
    exit 2
fi

VID="$1"
CIDR="$2"
GATEWAY="$3"
RACK_IP="$4"
DHCP_START="$5"
DHCP_END="$6"

MAAS_HOST="192.168.252.10"
PROFILE="Athari.Nima"

FABRIC_ID="2"
RACK_ID="q8cra3"
PARENT_IF_NAME="enp0s8"

ssh \
  -o ControlMaster=no \
  -o ControlPath=none \
  root@"$MAAS_HOST" bash -s -- \
    "$VID" \
    "$CIDR" \
    "$GATEWAY" \
    "$RACK_IP" \
    "$DHCP_START" \
    "$DHCP_END" \
    "$PROFILE" \
    "$FABRIC_ID" \
    "$RACK_ID" \
    "$PARENT_IF_NAME" <<'REMOTE'

set -euo pipefail

VID="$1"
CIDR="$2"
GATEWAY="$3"
RACK_IP="$4"
DHCP_START="$5"
DHCP_END="$6"

PROFILE="$7"
FABRIC_ID="$8"
RACK_ID="$9"
PARENT_IF_NAME="${10}"

echo "========================================"
echo "Ensuring MAAS VLAN $VID"
echo "CIDR      : $CIDR"
echo "Gateway   : $GATEWAY"
echo "Rack IP   : $RACK_IP"
echo "========================================"

# --------------------------------------------------
# 1. Ensure VLAN object exists in MAAS
# --------------------------------------------------

VLAN_INTERNAL_ID="$(
    maas "$PROFILE" vlans read "$FABRIC_ID" |
    jq -r --argjson vid "$VID" '
        .[] |
        select(.vid == $vid) |
        .id
    ' |
    head -1
)"

if [[ -z "$VLAN_INTERNAL_ID" ]]; then
    echo "Creating MAAS VLAN $VID..."

    VLAN_INTERNAL_ID="$(
        maas "$PROFILE" vlans create "$FABRIC_ID" \
            vid="$VID" \
            name="VLAN-${VID}" |
        jq -r '.id'
    )"
else
    echo "MAAS VLAN $VID already exists: ID=$VLAN_INTERNAL_ID"
fi


# --------------------------------------------------
# 2. Ensure subnet exists
# --------------------------------------------------

SUBNET_ID="$(
    maas "$PROFILE" subnets read |
    jq -r --arg cidr "$CIDR" '
        .[] |
        select(.cidr == $cidr) |
        .id
    ' |
    head -1
)"

if [[ -z "$SUBNET_ID" ]]; then
    echo "Creating subnet $CIDR..."

    SUBNET_ID="$(
        maas "$PROFILE" subnets create \
            cidr="$CIDR" \
            vlan="$VLAN_INTERNAL_ID" \
            gateway_ip="$GATEWAY" |
        jq -r '.id'
    )"
else
    echo "Subnet $CIDR already exists: ID=$SUBNET_ID"
fi


# --------------------------------------------------
# 3. Wait until Rack Controller sees VLAN interface
# --------------------------------------------------

echo "Waiting for Rack Controller to see VLAN $VID..."

RACK_VLAN_IF_ID=""

for attempt in $(seq 1 18); do

    RACK_VLAN_IF_ID="$(
        maas "$PROFILE" interfaces read "$RACK_ID" |
        jq -r --argjson vid "$VID" '
            .[] |
            select(.type == "vlan") |
            select(.vlan.vid == $vid) |
            .id
        ' |
        head -1
    )"

    if [[ -n "$RACK_VLAN_IF_ID" ]]; then
        echo "Rack Controller sees VLAN $VID: interface ID=$RACK_VLAN_IF_ID"
        break
    fi

    echo "Waiting for MAAS inventory refresh... attempt ${attempt}/18"
    sleep 5
done

if [[ -z "$RACK_VLAN_IF_ID" ]]; then
    echo "ERROR: Rack Controller did not discover VLAN $VID after 90 seconds." >&2
    echo "Expected interface: ${PARENT_IF_NAME}.${VID}" >&2
    exit 1
fi

# --------------------------------------------------
# 4. Ensure dynamic DHCP range exists
# --------------------------------------------------

RANGE_ID="$(
    maas "$PROFILE" ipranges read |
    jq -r \
        --arg cidr "$CIDR" \
        --arg start "$DHCP_START" \
        --arg end "$DHCP_END" '
        .[] |
        select(.type == "dynamic") |
        select(.subnet.cidr == $cidr) |
        select(.start_ip == $start) |
        select(.end_ip == $end) |
        .id
    ' |
    head -1
)"

if [[ -z "$RANGE_ID" ]]; then
    echo "Creating DHCP range..."

    maas "$PROFILE" ipranges create \
        type=dynamic \
        subnet="$SUBNET_ID" \
        start_ip="$DHCP_START" \
        end_ip="$DHCP_END" >/dev/null
else
    echo "DHCP range already exists: ID=$RANGE_ID"
fi


# --------------------------------------------------
# 5. Enable DHCP on VLAN
# --------------------------------------------------

DHCP_ON="$(
    maas "$PROFILE" vlan read "$FABRIC_ID" "$VID" |
    jq -r '.dhcp_on'
)"

PRIMARY_RACK="$(
    maas "$PROFILE" vlan read "$FABRIC_ID" "$VID" |
    jq -r '.primary_rack // ""'
)"

if [[ "$DHCP_ON" != "true" || "$PRIMARY_RACK" != "$RACK_ID" ]]; then
    echo "Enabling DHCP on VLAN $VID..."

    maas "$PROFILE" vlan update \
        "$FABRIC_ID" \
        "$VID" \
        dhcp_on=true \
        primary_rack="$RACK_ID" >/dev/null
else
    echo "DHCP already enabled on VLAN $VID."
fi

echo
echo "MAAS VLAN $VID is ready."

REMOTE
