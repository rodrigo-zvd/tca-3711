locals {
  pool = {
    name = var.pool_name
    sr   = var.pool_sr
  }

  network = {
    vlan    = "LAN"
    netmask = "24"
    cidr    = "192.168.1.0/24"
    gateway = "192.168.1.1"
    dns1    = "8.8.8.8"
    dns2    = "8.8.4.4"
    domain  = "cvsl.intraer"
  }
  vms = {
    xenorchestra = {
      # vm name
      name = "Xen Orchestra - TCA3711"

      # vm template
      template = "template-ubuntu-24"

      # vm network
      network = {
        ip = "192.168.1.40"
      }

      cloud_init = {
        cloud_config = {
          manage_etc_hosts = true
          timezone         = "America/Sao_Paulo"
          locale           = "pt_BR.utf8"
          keyboard_layout  = "br"
          user             = "ubuntu"
          password         = "ubuntu"
          chpasswd         = false
          ssh_pwauth       = true
          ssh_public_key   = file("/home/rodrigo/.ssh/id_ed25519.pub")
          package_update   = true
          package_upgrade  = true
        }
        network_config = {
          device = "enX0"
        }
      }

      # hardware info
      cores     = 4
      memory_gb = 4
      disks = {
        xvda = {
          name    = "xvda"
          size_gb = 30
        }
      }

      tags = "Xen Orchestra - TCA3711"
    }
  }

  # Convert all disk sizes from GB to bytes (support multiple disks per VM)
  disk_size_to_bytes = {
    for vm_name, vm in local.vms : vm_name => {
      for disk_name, disk in vm.disks : disk_name => disk.size_gb * 1024 * 1024 * 1024
    }
  }

  # Convert memory values from GB to bytes
  memory_size_to_bytes = {
    for k, v in local.vms : k => {
      memory = v.memory_gb * 1024 * 1024 * 1024
    }
  }
}