vlans = {
  "721" = {
    description = "Software"
    subnet      = "172.19.1.0/24"
    gateway     = "172.19.1.1"
    rack_ip     = "172.19.1.10"
    dhcp_start  = "172.19.1.191"
    dhcp_end    = "172.19.1.254"
  }

  "761" = {
    description = "Information Technology"
    subnet      = "172.16.1.0/24"
    gateway     = "172.16.1.1"
    rack_ip     = "172.16.1.10"
    dhcp_start  = "172.16.1.250"
    dhcp_end    = "172.16.1.254"
  }

  "781" = {
    description = "DevOps"
    subnet      = "172.18.1.0/24"
    gateway     = "172.18.1.1"
    rack_ip     = "172.18.1.10"
    dhcp_start  = "172.18.1.250"
    dhcp_end    = "172.18.1.254"
  }

  "850" = {
    description = "Terraform-Test"
    subnet      = "172.30.50.0/24"
    gateway     = "172.30.50.1"
    rack_ip     = "172.30.50.10"
    dhcp_start  = "172.30.50.191"
    dhcp_end    = "172.30.50.254"
  }
  "851" = {
    description = "Terraform-Test-2"
    subnet      = "172.30.51.0/24"
    gateway     = "172.30.51.1"
    rack_ip     = "172.30.51.10"
    dhcp_start  = "172.30.51.191"
    dhcp_end    = "172.30.51.254"
  }
  "852" = {
    description = "Terraform-Test-3"
    subnet      = "172.30.52.0/24"
    gateway     = "172.30.52.1"
    rack_ip     = "172.30.52.10"
    dhcp_start  = "172.30.52.191"
    dhcp_end    = "172.30.52.254"
  }
}

nodes = {
  node01 = {
    vm_name   = "Node01"
    vlan_id   = 781
    memory_mb = 2048
    cpus      = 1
    disk_gb   = 20

    provision = false
  }

  node02 = {
    vm_name   = "Node02"
    vlan_id   = 761
    memory_mb = 4096
    cpus      = 1
    disk_gb   = 20

    workload_ip = "172.16.1.23"

    workload_mac = "08002766ADD6"
    pxe_mac      = "08002719E757"

    provision = true
  }

  node03 = {
    vm_name   = "Node03"
    vlan_id   = 721
    memory_mb = 4096
    cpus      = 1
    disk_gb   = 20

    workload_ip = "172.19.1.23"

    workload_mac = "080027FC768D"
    pxe_mac      = "080027FB0FC6"

    provision = true
  }

  node04 = {
    vm_name   = "Node04"
    vlan_id   = 721
    memory_mb = 4096
    cpus      = 1
    disk_gb   = 20

    workload_ip = "172.19.1.24"

    workload_mac = "080027040002"
    pxe_mac      = "080027040003"

    provision = true
  }

  node05 = {
    vm_name     = "Node05"
    vlan_id     = 721
    memory_mb   = 4096
    cpus        = 1
    disk_gb     = 20
    workload_ip = "172.19.1.25"

    workload_mac = "080027050002"
    pxe_mac      = "080027050003"

    provision = true
  }

  asma-wp-test = {
    vm_name     = "Asma-WP-Test"
    vlan_id     = 721
    memory_mb   = 4096
    cpus        = 2
    disk_gb     = 25
    workload_ip = "172.19.1.100"

    workload_mac = "080027050002"
    pxe_mac      = "080027050003"

    provision = true
  }

}
