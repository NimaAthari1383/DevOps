#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 4 ]]; then
    echo "Usage: $0 <HOSTNAME> <MGMT_IP> <WORKLOAD_IP> <SYSTEM_ID>" >&2
    exit 2
fi

HOSTNAME="$1"
MGMT_IP="$2"
WORKLOAD_IP="$3"
SYSTEM_ID="$4"

ENV_FILE="${HOME}/.config/terraform-maas-lab/awx.env"

[[ -r "$ENV_FILE" ]] || {
    echo "ERROR: AWX env file not found: $ENV_FILE" >&2
    exit 1
}

# shellcheck disable=SC1090
source "$ENV_FILE"

: "${AWX_URL:?AWX_URL is not set}"
: "${AWX_USER:?AWX_USER is not set}"
: "${AWX_PASS:?AWX_PASS is not set}"
: "${AWX_INVENTORY_ID:?AWX_INVENTORY_ID is not set}"
: "${AWX_TEMPLATE_ID:?AWX_TEMPLATE_ID is not set}"

AWX_URL="${AWX_URL%/}"

log() {
    printf '[AWX] %s\n' "$*"
}

die() {
    echo "ERROR: $*" >&2
    exit 1
}

awx_get() {
    local endpoint="$1"

    curl \
        -k \
        --noproxy '*' \
        -fsS \
        -u "${AWX_USER}:${AWX_PASS}" \
        "${AWX_URL}${endpoint}"
}

awx_post() {
    local endpoint="$1"
    local payload="$2"

    curl \
        -k \
        --noproxy '*' \
        -fsS \
        -u "${AWX_USER}:${AWX_PASS}" \
        -H 'Content-Type: application/json' \
        -X POST \
        "${AWX_URL}${endpoint}" \
        -d "$payload"
}

awx_patch() {
    local endpoint="$1"
    local payload="$2"

    curl \
        -k \
        --noproxy '*' \
        -fsS \
        -u "${AWX_USER}:${AWX_PASS}" \
        -H 'Content-Type: application/json' \
        -X PATCH \
        "${AWX_URL}${endpoint}" \
        -d "$payload"
}

log "Checking AWX API"

awx_get "/api/v2/ping/" >/dev/null ||
    die "AWX API is not reachable"

log "Looking for host '$HOSTNAME' in inventory $AWX_INVENTORY_ID"

HOST_SEARCH="$(
    awx_get \
        "/api/v2/inventories/${AWX_INVENTORY_ID}/hosts/?name=${HOSTNAME}"
)"

HOST_ID="$(
    jq -r '.results[0].id // empty' <<<"$HOST_SEARCH"
)"

HOST_VARS="$(
    jq -n \
        --arg ansible_host "$MGMT_IP" \
        --arg workload_ip "$WORKLOAD_IP" \
        --arg maas_system_id "$SYSTEM_ID" \
        '{
          ansible_host: $ansible_host,
          workload_ip: $workload_ip,
          maas_system_id: $maas_system_id
        }'
)"

HOST_PAYLOAD="$(
    jq -n \
        --arg name "$HOSTNAME" \
        --arg variables "$HOST_VARS" \
        '{
          name: $name,
          enabled: true,
          variables: $variables
        }'
)"

if [[ -z "$HOST_ID" ]]; then
    log "Creating AWX host '$HOSTNAME'"

    CREATE_RESPONSE="$(
        awx_post \
            "/api/v2/inventories/${AWX_INVENTORY_ID}/hosts/" \
            "$HOST_PAYLOAD"
    )"

    HOST_ID="$(
        jq -r '.id // empty' <<<"$CREATE_RESPONSE"
    )"

    [[ -n "$HOST_ID" ]] ||
        die "AWX host creation did not return an ID"

else
    log "Updating existing AWX host '$HOSTNAME' (id=$HOST_ID)"

    awx_patch \
        "/api/v2/hosts/${HOST_ID}/" \
        "$HOST_PAYLOAD" \
        >/dev/null
fi

log "AWX host ready: id=$HOST_ID"

LAUNCH_PAYLOAD="$(
    jq -n \
        --arg limit "$HOSTNAME" \
        --arg hostname "$HOSTNAME" \
        --arg mgmt_ip "$MGMT_IP" \
        --arg workload_ip "$WORKLOAD_IP" \
        --arg system_id "$SYSTEM_ID" \
        '{
          limit: $limit,
          extra_vars: {
            target_hostname: $hostname,
            target_management_ip: $mgmt_ip,
            target_workload_ip: $workload_ip,
            maas_system_id: $system_id
          }
        }'
)"

log "Launching template $AWX_TEMPLATE_ID with limit=$HOSTNAME"

LAUNCH_RESPONSE="$(
    awx_post \
        "/api/v2/job_templates/${AWX_TEMPLATE_ID}/launch/" \
        "$LAUNCH_PAYLOAD"
)"

JOB_ID="$(
    jq -r '.job // .id // empty' <<<"$LAUNCH_RESPONSE"
)"

[[ -n "$JOB_ID" ]] ||
    die "AWX launch did not return a job ID"

log "AWX job ID: $JOB_ID"

for attempt in $(seq 1 180); do
    JOB="$(
        awx_get "/api/v2/jobs/${JOB_ID}/"
    )"

    STATUS="$(
        jq -r '.status // empty' <<<"$JOB"
    )"

    printf '[AWX %03d/180] job=%s status=%s\n' \
        "$attempt" "$JOB_ID" "$STATUS"

    case "$STATUS" in
        successful)
            log "AWX job completed successfully"
            exit 0
            ;;

        failed|error|canceled)
            jq '{
              id,
              name,
              status,
              failed,
              started,
              finished
            }' <<<"$JOB" >&2

            die "AWX job ended with status=$STATUS"
            ;;

        new|pending|waiting|running)
            ;;

        *)
            log "Non-terminal/unknown status: $STATUS"
            ;;
    esac

    sleep 10
done

die "Timeout waiting for AWX job $JOB_ID"
