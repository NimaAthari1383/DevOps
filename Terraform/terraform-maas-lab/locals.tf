locals {
  vlan_ids = sort([for vlan_id in keys(var.vlans) : tonumber(vlan_id)])

  managed_nodes = {
    for name, node in var.nodes :
    name => node
    if try(node.provision, true)
  }
}
