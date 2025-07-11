locals {

  count = 1

  vlan_lab = {
    cidr    = "192.168.1.0/24"
    gateway = "192.168.1.1"
    dns1    = "8.8.8.8"
    dns2    = "8.8.4.4"
    domain  = "cvsl.intraer"
  }

  pool = {
    name = "xcp-optiplex"
    sr   = "Local storage"
  }

  networks = {
    wan = {
      name = "LAN"
      cidr = "192.168.1.0/24"
    }
    vlans = {
      vlan1 = {
        name              = "vlan1"
        cidr              = "10.0.1.0/24"
        source_pif_device = "eth0"
        id_prefix         = "3"
        id_suffix         = "1"
      }
      vlan2 = {
        name              = "vlan2"
        cidr              = "10.0.2.0/24"
        source_pif_device = "eth0"
        id_prefix         = "3"
        id_suffix         = "2"
      }
      vlan3 = {
        name              = "vlan3"
        cidr              = "10.0.3.0/24"
        source_pif_device = "eth0"
        id_prefix         = "3"
        id_suffix         = "3"
      }
      san = {
        name              = "san"
        cidr              = "192.168.100.0/24"
        source_pif_device = "eth0"
        id_prefix         = "3"
        id_suffix         = "4"
        mtu               = "9000"
      }
    }
  }

  vms = {
    opnsense = {
      name = "opnsense"

      template = "template-opnsense-lab-cloudinit"

      cores     = 2
      memory_gb = 2

      disks = {
        xvda = {
          name    = "xvda"
          size_gb = 40
        }
      }

      network_last_octect = 30

      cloud_init = {
        cloud_config = {
          template_xml = "/conf/config-cloud-init.xml"
          target_xml   = "/conf/config.xml"
          wan_if       = "xn1"
          # ip           = "192.168.1.50"
          subnet  = "24"
          gateway = "192.168.1.1"
          dns     = "8.8.8.8"
        }
      }

      tags = "opnsense"

    }
    xcp1 = {
      name = "xcp1"

      template = "template-xcp-ng-8.3.0-id-1"

      cores     = 4
      memory_gb = 4

      disks = {
        xvda = {
          name    = "xvda"
          size_gb = 100
        }
      }

      cloud_init = {
        cloud_config = {
          configure_network = "true" # Set to "true" to apply network settings, "false" to skip.
          # --- Network Settings (Only applied if CONFIGURE_NETWORK is "true") ---
          # Example values; REPLACE WITH YOUR ACTUAL NETWORK SETTINGS
          ip          = "10.0.1.10"     # New IP address for the XCP-ng host
          netmask     = "255.255.255.0" # New subnet mask
          gateway     = "10.0.1.1"      # New default gateway
          dns_servers = "10.0.1.1"      # New DNS servers (comma-separated, e.g., "8.8.8.8,8.8.4.4")
          # --- Hostname Configuration ---
          set_hostname = "true" # Set to "true" to change hostname, "false" to skip
          hostname     = "xcp1" # Desired new hostname
          # --- User and Password Management ---
          # You can set both CREATE_NEW_USER and ROOT_PASSWORD_CHANGE to "true" simultaneously.
          create_new_user        = "false"                 # Set to "true" to create a new user, "false" to skip
          new_ssh_username       = "xcpadmin"              # Username for the new SSH user
          new_user_password      = "NewStrongPassword123!" # Password for the new SSH user (MAKE THIS VERY STRONG AND UNIQUE!)
          add_user_to_sudo_group = "true"                  # Set to "true" to add the new user to the 'wheel' group (for sudo)

          root_password_change = "true"   # Set to "true" to change root password directly, "false" to skip
          new_root_password    = "123456" # New password for the root user (MAKE THIS VERY STRONG AND UNIQUE!)

          # --- SSH Public Key Configuration ---
          add_ssh_keys = "true" # Set to "true" to add SSH public keys, "false" to skip
          # Provide one or more public keys, each on a new line within the heredoc.
          # Ensure correct formatting (e.g., "ssh-rsa AAAAB3NzaC... user@example.com")
          # Use 'EOF' without quotes (as done here) to prevent shell variable expansion in the keys themselves.
          # ssh_public_keys = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAN3JnFSajM3rl8Dg6Pj/ffFpE4dYK9dEiftI2Y2Cke0 rodrigo@YogaSlim6"
          ssh_public_keys = file("id_ed25519.pub")

          # --- Timezone Configuration ---
          set_timezone = "true"           # Set to "true" to change timezone, "false" to skip
          new_timezone = "America/Manaus" # Example: "America/New_York", "Europe/London", "Asia/Tokyo"
          # Find valid timezones with 'timedatectl list-timezones'
        }
      }

      tags = "xcp1"

    }

    xcp2 = {
      name = "xcp2"

      template = "template-xcp-ng-8.3.0-id-2"

      cores     = 4
      memory_gb = 4

      disks = {
        xvda = {
          name    = "xvda"
          size_gb = 100
        }
      }

      cloud_init = {
        cloud_config = {
          configure_network = "true" # Set to "true" to apply network settings, "false" to skip.
          # --- Network Settings (Only applied if CONFIGURE_NETWORK is "true") ---
          # Example values; REPLACE WITH YOUR ACTUAL NETWORK SETTINGS
          ip          = "10.0.1.11"     # New IP address for the XCP-ng host
          netmask     = "255.255.255.0" # New subnet mask
          gateway     = "10.0.1.1"      # New default gateway
          dns_servers = "10.0.1.1"      # New DNS servers (comma-separated, e.g., "8.8.8.8,8.8.4.4")
          # --- Hostname Configuration ---
          set_hostname = "true" # Set to "true" to change hostname, "false" to skip
          hostname     = "xcp2" # Desired new hostname
          # --- User and Password Management ---
          # You can set both CREATE_NEW_USER and ROOT_PASSWORD_CHANGE to "true" simultaneously.
          create_new_user        = "false"                 # Set to "true" to create a new user, "false" to skip
          new_ssh_username       = "xcpadmin"              # Username for the new SSH user
          new_user_password      = "NewStrongPassword123!" # Password for the new SSH user (MAKE THIS VERY STRONG AND UNIQUE!)
          add_user_to_sudo_group = "true"                  # Set to "true" to add the new user to the 'wheel' group (for sudo)

          root_password_change = "true"   # Set to "true" to change root password directly, "false" to skip
          new_root_password    = "123456" # New password for the root user (MAKE THIS VERY STRONG AND UNIQUE!)

          # --- SSH Public Key Configuration ---
          add_ssh_keys = "true" # Set to "true" to add SSH public keys, "false" to skip
          # Provide one or more public keys, each on a new line within the heredoc.
          # Ensure correct formatting (e.g., "ssh-rsa AAAAB3NzaC... user@example.com")
          # Use 'EOF' without quotes (as done here) to prevent shell variable expansion in the keys themselves.
          # ssh_public_keys = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAN3JnFSajM3rl8Dg6Pj/ffFpE4dYK9dEiftI2Y2Cke0 rodrigo@YogaSlim6"
          ssh_public_keys = file("id_ed25519.pub")

          # --- Timezone Configuration ---
          set_timezone = "true"           # Set to "true" to change timezone, "false" to skip
          new_timezone = "America/Manaus" # Example: "America/New_York", "Europe/London", "Asia/Tokyo"
          # Find valid timezones with 'timedatectl list-timezones'
        }
      }

      tags = "xcp2"

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

