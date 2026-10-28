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
  description = "VirtualBox + MAAS node definitions"

  type = map(object({
    vm_name   = string
    vlan_id   = number
    memory_mb = number
    cpus      = number
    disk_gb   = number

    # Static workload IP assigned by MAAS.
    workload_ip = optional(string)

    # Two-NIC architecture:
    # NIC1 = PXE / Management
    # NIC2 = Workload VLAN
    workload_mac = optional(string)
    pxe_mac      = optional(string)

    # false = protect node from provisioning lifecycle.
    provision = optional(bool, true)
  }))
}

variable "maas_host" {
  type    = string
  default = "192.168.252.10"
}

variable "maas_profile" {
  type    = string
  default = "Athari.Nima"
}

variable "maas_fabric_id" {
  type    = number
  default = 2
}

variable "maas_management_subnet" {
  type    = string
  default = "192.168.252.0/24"
}

variable "maas_management_gateway" {
  description = "MikroTik gateway for the MAAS management/PXE subnet"
  type        = string
  default     = "192.168.252.1"
}

variable "virtualbox_vm_base_dir" {
  description = "VirtualBox base directory for managed VMs"
  type        = string
  default     = "/home/nimaathari/1-nima_files/Program_Files/VirtualBox VMs"
}
