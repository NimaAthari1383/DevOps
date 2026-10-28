variable "vlans" {
  description = "MAAS workload VLAN definitions"

  type = map(object({
    description = string

    subnet  = string
    gateway = string
    rack_ip = string

    dhcp_start = string
    dhcp_end   = string
  }))
}

variable "nodes" {
  type = map(object({
    vm_name   = string
    vlan_id   = number
    memory_mb = number
    cpus      = number
    disk_gb   = number
  }))
}
