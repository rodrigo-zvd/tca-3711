data "xenorchestra_template" "template" {
  name_label = local.vms.xenorchestra.template
  pool_id    = data.xenorchestra_pool.pool.id
}

data "xenorchestra_network" "network-xenorchestra" {
  name_label = local.network.vlan
  pool_id    = data.xenorchestra_pool.pool.id
}

resource "xenorchestra_vm" "xenorchestra" {

  #name of vm
  name_label = local.vms.xenorchestra.name

  #core cpu
  cpus = local.vms.xenorchestra.cores

  #memory ram
  memory_max = local.memory_size_to_bytes.xenorchestra.memory

  #template
  template = data.xenorchestra_template.template.id

  #cloud-init config
  cloud_config = templatefile("cloud_config.tftpl", {
    hostname         = "xo-tca3711"
    domain           = local.network.domain
    manage_etc_hosts = local.vms.xenorchestra.cloud_init.cloud_config.manage_etc_hosts
    timezone         = local.vms.xenorchestra.cloud_init.cloud_config.timezone
    locale           = local.vms.xenorchestra.cloud_init.cloud_config.locale
    keyboard_layout  = local.vms.xenorchestra.cloud_init.cloud_config.keyboard_layout
    user             = local.vms.xenorchestra.cloud_init.cloud_config.user
    password         = local.vms.xenorchestra.cloud_init.cloud_config.password
    chpasswd         = local.vms.xenorchestra.cloud_init.cloud_config.chpasswd
    ssh_pwauth       = local.vms.xenorchestra.cloud_init.cloud_config.ssh_pwauth
    ssh_public_key   = local.vms.xenorchestra.cloud_init.cloud_config.ssh_public_key
    package_update   = local.vms.xenorchestra.cloud_init.cloud_config.package_update
    package_upgrade  = local.vms.xenorchestra.cloud_init.cloud_config.package_upgrade
  })
  #cloud-init network
  cloud_network_config = templatefile("network_config.tftpl", {
    device = local.vms.xenorchestra.cloud_init.network_config.device
    ip = format(
      "%s/24",
      local.vms.xenorchestra.network.ip
    )
    gateway = local.network.gateway
    dns1    = local.network.dns1
    dns2    = local.network.dns2
  })

  #network of vm
  network {
    network_id = data.xenorchestra_network.network-xenorchestra.id
    expected_ip_cidr = format(
      "%s%s",
      local.vms.xenorchestra.network.ip,
      "/32"
    )
  }

  #disk of vm
  disk {
    sr_id = data.xenorchestra_sr.sr.id
    name_label = format(
      "%s-%s",
      local.vms.xenorchestra.name,
      local.vms.xenorchestra.disks.xvda.name
    )
    size = local.disk_size_to_bytes.xenorchestra.xvda
  }
  #extra configuration
  destroy_cloud_config_vdi_after_boot = "true"
  auto_poweron                        = "true"

  #tags of vm
  tags = [
    local.vms.xenorchestra.tags
  ]

  # connection ssh to vm
  connection {
    type     = "ssh"
    user     = local.vms.xenorchestra.cloud_init.cloud_config.user
    password = local.vms.xenorchestra.cloud_init.cloud_config.password
    # private_key = file("id_ed25519")
    host = local.vms.xenorchestra.network.ip
  }
  # wait for cloud-init done
  provisioner "remote-exec" {
    inline = [
      "cloud-init status --wait | grep -q 'status: done' && exit 0 || exit 1"
    ]

  }
}