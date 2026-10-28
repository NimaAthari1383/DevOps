resource "terraform_data" "ovs_trunk" {
  provisioner "local-exec" {
    command     = "${path.module}/scripts/ensure-trunk.sh"
    working_dir = path.module
  }
}


# --------------------------------------------------
# Host-side OVS access networks
# --------------------------------------------------

resource "terraform_data" "vlans" {
  for_each = var.vlans

  input = {
    vlan_id     = tonumber(each.key)
    description = each.value.description
  }

  depends_on = [
    terraform_data.ovs_trunk
  ]

  provisioner "local-exec" {
    command = "${path.module}/scripts/ensure-vlan-access.sh ${each.key}"
  }
}


# --------------------------------------------------
# Create VLAN/Subnet objects in MAAS first
# --------------------------------------------------

resource "terraform_data" "maas_vlan_base" {
  for_each = var.vlans

  triggers_replace = [
    each.key,
    each.value.subnet,
    each.value.gateway
  ]

  depends_on = [
    terraform_data.vlans
  ]

  provisioner "local-exec" {
    command = join(" ", [
      "${path.module}/scripts/ensure-maas-base.sh",
      each.key,
      each.value.subnet,
      each.value.gateway
    ])
  }
}


# --------------------------------------------------
# Generate/apply persistent Netplan on Rack Controller
# --------------------------------------------------

resource "terraform_data" "maas_netplan" {
  triggers_replace = [
    jsonencode(var.vlans)
  ]

  depends_on = [
    terraform_data.maas_vlan_base
  ]

  provisioner "local-exec" {
    command = "${path.module}/scripts/sync-maas-netplan.sh"

    environment = {
      VLANS_JSON = jsonencode(var.vlans)
    }
  }
}


# --------------------------------------------------
# Finish MAAS VLAN: rack interface + DHCP
# --------------------------------------------------

resource "terraform_data" "maas_vlans" {
  for_each = var.vlans

  triggers_replace = [
    each.key,
    each.value.subnet,
    each.value.gateway,
    each.value.rack_ip,
    each.value.dhcp_start,
    each.value.dhcp_end
  ]

  depends_on = [
    terraform_data.maas_netplan
  ]

  provisioner "local-exec" {
    command = join(" ", [
      "${path.module}/scripts/ensure-maas-vlan.sh",
      each.key,
      each.value.subnet,
      each.value.gateway,
      each.value.rack_ip,
      each.value.dhcp_start,
      each.value.dhcp_end
    ])
  }
}
