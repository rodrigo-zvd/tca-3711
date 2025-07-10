data "xenorchestra_template" "template-opnsense" {
  name_label = local.vms.opnsense.template
}

resource "xenorchestra_vm" "opnsense" {
  #number of vms
  count = local.count

  #name of vm
  name_label = format(
    "lab%02d-%s",
    count.index,
    local.vms.opnsense.name
  )

  #core cpu
  cpus = local.vms.opnsense.cores

  #memory ram
  memory_max = local.memory_size_to_bytes.opnsense.memory

  #configuration of vm
  template = data.xenorchestra_template.template-opnsense.id

  cloud_config = templatefile("cloud-config-opnsense.tftpl", {
    TEMPLATE_XML = local.vms.opnsense.cloud_init.cloud_config.template_xml
    TARGET_XML   = local.vms.opnsense.cloud_init.cloud_config.target_xml
    WAN_IF       = local.vms.opnsense.cloud_init.cloud_config.wan_if
    # IP           = local.vms.opnsense.cloud_init.cloud_config.ip
    IP = format(
      "%s",
      cidrhost(
        local.vlan_lab.cidr,
        local.vms.opnsense.network_last_octect + count.index
      )
    )
    SUBNET  = local.vms.opnsense.cloud_init.cloud_config.subnet
    GATEWAY = local.vms.opnsense.cloud_init.cloud_config.gateway
    DNS     = local.vms.opnsense.cloud_init.cloud_config.dns
  })
  #extra configuration
  auto_poweron = "true"

  #network of vm
  #vlan1 
  network {
    network_id       = xenorchestra_network.vlan_1[count.index].id
    expected_ip_cidr = local.networks.vlans.vlan1.cidr
  }
  #wan
  network {
    network_id = data.xenorchestra_network.wan.id
    expected_ip_cidr = format(
      "%s/32",
      cidrhost(
        local.vlan_lab.cidr,
        local.vms.opnsense.network_last_octect + count.index
      )
    )
  }
  #vlan2
  network {
    network_id       = xenorchestra_network.vlan_2[count.index].id
    expected_ip_cidr = local.networks.vlans.vlan2.cidr

  }
  #vlan3
  network {
    network_id       = xenorchestra_network.vlan_3[count.index].id
    expected_ip_cidr = local.networks.vlans.vlan3.cidr
  }


  #disk of vm
  disk {
    sr_id = data.xenorchestra_sr.sr.id
    name_label = format(
      "%s-%s-%s",
      local.vms.opnsense.name,
      count.index,
      local.vms.opnsense.disks.xvda.name
    )
    size = local.disk_size_to_bytes.opnsense.xvda
  }

  #tags of vm
  tags = [
    format("lab%02d", count.index),
    local.vms.opnsense.tags
  ]


  # SSH connection details for the OPNsense VM
  connection {
    type = "ssh"
    user = "root" # SSH user on the OPNsense VM
    # private_key = file("~/.ssh/id_rsa") # Path to your SSH private key
    # Or 'password = "your_password"' (with due security considerations)
    password = "opnsense"
    host = format(
      "%s",
      cidrhost(
        local.vlan_lab.cidr,
        local.vms.opnsense.network_last_octect + count.index
      )
    )
    timeout = "15m" # Maximum time to establish the SSH connection
  }

  provisioner "remote-exec" {
    inline = [
      "echo 'SSH connection to OPNsense VM established successfully!'",
      "echo 'Attempting to list files in /tmp to confirm SSH is working...'",
      "ls -la /tmp", # A simple command to confirm shell access
      "echo 'SSH verification complete.'"
    ]
  }
}