resource "terraform_data" "node_vm_config" {
  for_each = var.nodes

  triggers_replace = [
    each.value.vm_name,
    tostring(each.value.memory_mb),
    tostring(each.value.cpus),
    tostring(each.value.disk_gb),
    tostring(each.value.vlan_id)
  ]

  depends_on = [
    terraform_data.maas_vlans
  ]

  provisioner "local-exec" {
    command = join(" ", [
      "${path.module}/scripts/ensure-vm.sh",
      "\"${each.value.vm_name}\"",
      tostring(each.value.memory_mb),
      tostring(each.value.cpus),
      tostring(each.value.disk_gb),
      tostring(each.value.vlan_id)
    ])
  }
}
