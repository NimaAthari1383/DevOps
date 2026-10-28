resource "terraform_data" "maas_management_subnet" {
  triggers_replace = [
    var.maas_host,
    var.maas_profile,
    var.maas_management_subnet,
    var.maas_management_gateway,
    "dns=${var.maas_host}",
  ]

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]

    command = <<-EOT
      set -euo pipefail

      SUBNET_ID="$(
        ssh \
          -o ControlMaster=no \
          -o ControlPath=none \
          root@${var.maas_host} \
          'maas ${var.maas_profile} subnets read' |
        jq -r \
          --arg cidr '${var.maas_management_subnet}' \
          '.[] | select(.cidr == $cidr) | .id'
      )"

      if [[ -z "$SUBNET_ID" ]]; then
        echo "ERROR: management subnet ${var.maas_management_subnet} not found" >&2
        exit 1
      fi

      echo "Managing MAAS management subnet ID=$SUBNET_ID"

      ssh \
        -o ControlMaster=no \
        -o ControlPath=none \
        root@${var.maas_host} \
        "maas ${var.maas_profile} subnet update \
          $SUBNET_ID \
          gateway_ip=${var.maas_management_gateway} \
          dns_servers=${var.maas_host}" \
        >/dev/null

      RESULT="$(
        ssh \
          -o ControlMaster=no \
          -o ControlPath=none \
          root@${var.maas_host} \
          "maas ${var.maas_profile} subnet read $SUBNET_ID"
      )"

      GATEWAY="$(jq -r '.gateway_ip // empty' <<<"$RESULT")"
      DNS="$(jq -r '.dns_servers | join(",")' <<<"$RESULT")"

      if [[ "$GATEWAY" != "${var.maas_management_gateway}" ]]; then
        echo "ERROR: management gateway is '$GATEWAY'" >&2
        echo "Expected '${var.maas_management_gateway}'" >&2
        exit 1
      fi

      if [[ "$DNS" != "${var.maas_host}" ]]; then
        echo "ERROR: management DNS is '$DNS'" >&2
        echo "Expected '${var.maas_host}'" >&2
        exit 1
      fi

      echo "MAAS management subnet verified:"
      echo "  CIDR    = ${var.maas_management_subnet}"
      echo "  Gateway = ${var.maas_management_gateway}"
      echo "  DNS     = ${var.maas_host}"
    EOT
  }
}
