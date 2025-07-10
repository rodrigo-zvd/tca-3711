locals {
  pool = {
    name = var.pool_name
    sr   = var.pool_sr
  }

  template-xcp = {
    # vm name
    name = "xcpng-cloutinit"

    # vm template
    template = "CentOS 7"

    # vm network
    network = {
      vlan    = var.vm_template_vlan
      ip      = var.vm_template_ip
      netmask = var.vm_template_netmask
      gateway = var.vm_template_gateway
    }

    auth = {
      user     = var.vm_template_user
      password = var.vm_template_password
    }

    # hardware info
    cores  = 4
    memory = 4294967296 # in bytes
    disks = {
      xvda = {
        name = "xvda"
        size = 107374182400 #in bytes
      }
    }
    cdrom = var.vm_template_iso

    tags = "XCP-ng Nested"
  }
}