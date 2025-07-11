# data "xenorchestra_template" "template-xcp1" {
#   name_label = local.vms.xcp1.template
# }

# resource "xenorchestra_vm" "xcp1" {
#   #number of vms
#   count = local.count

#   #name of vm
#   name_label = format(
#     "lab%02d-%s",
#     count.index,
#     local.vms.xcp1.name
#   )

#   #core cpu
#   cpus = local.vms.xcp1.cores

#   #memory ram
#   memory_max = local.memory_size_to_bytes.xcp1.memory

#   #configuration of vm
#   template = data.xenorchestra_template.template-xcp1.id

#   cloud_config = templatefile("cloud-config-xcp.sh", {
#     CONFIGURE_NETWORK_PLACEHOLDER      = local.vms.xcp1.cloud_init.cloud_config.configure_network
#     IP_PLACEHOLDER                     = local.vms.xcp1.cloud_init.cloud_config.ip
#     NETMASK_PLACEHOLDER                = local.vms.xcp1.cloud_init.cloud_config.netmask
#     GATEWAY_PLACEHOLDER                = local.vms.xcp1.cloud_init.cloud_config.gateway
#     DNS_SERVERS_PLACEHOLDER            = local.vms.xcp1.cloud_init.cloud_config.dns_servers
#     SET_HOSTNAME_PLACEHOLDER           = local.vms.xcp1.cloud_init.cloud_config.set_hostname
#     HOSTNAME_PLACEHOLDER               = local.vms.xcp1.cloud_init.cloud_config.hostname
#     CREATE_NEW_USER_PLACEHOLDER        = local.vms.xcp1.cloud_init.cloud_config.create_new_user
#     NEW_SSH_USER_PLACEHOLDER           = local.vms.xcp1.cloud_init.cloud_config.new_ssh_username
#     NEW_USER_PASSWORD_PLACEHOLDER      = local.vms.xcp1.cloud_init.cloud_config.new_user_password
#     ADD_USER_TO_SUDO_GROUP_PLACEHOLDER = local.vms.xcp1.cloud_init.cloud_config.add_user_to_sudo_group
#     ROOT_PASSWORD_CHANGE_PLACEHOLDER   = local.vms.xcp1.cloud_init.cloud_config.root_password_change
#     NEW_ROOT_PASSWORD_PLACEHOLDER      = local.vms.xcp1.cloud_init.cloud_config.new_root_password
#     ADD_SSH_KEYS_PLACEHOLDER           = local.vms.xcp1.cloud_init.cloud_config.add_ssh_keys
#     SSH_PUBLIC_KEYS_PLACEHOLDER        = local.vms.xcp1.cloud_init.cloud_config.ssh_public_keys
#     SET_TIMEZONE_PLACEHOLDER           = local.vms.xcp1.cloud_init.cloud_config.set_timezone
#     NEW_TIMEZONE_PLACEHOLDER           = local.vms.xcp1.cloud_init.cloud_config.new_timezone

#   })
#   #extra configuration//////
#   auto_poweron   = "true"
#   exp_nested_hvm = "true"

#   #network of vm
#   #vlan1 
#   network {
#     network_id = xenorchestra_network.vlan_1[count.index].id
#   }
#   #trunk
#   network {
#     network_id = xenorchestra_network.vlan_2[count.index].id
#   }
#   #san
#   network {
#     network_id = xenorchestra_network.vlan_san[count.index].id
#   }
#   #san
#   network {
#     network_id = xenorchestra_network.vlan_san[count.index].id
#   }

#   #disk of vm
#   disk {
#     sr_id = data.xenorchestra_sr.sr.id
#     name_label = format(
#       "%s-%s-%s",
#       local.vms.xcp1.name,
#       count.index,
#       local.vms.xcp1.disks.xvda.name
#     )
#     size = local.disk_size_to_bytes.xcp1.xvda
#   }

#   #tags of vm
#   tags = [
#     format("lab%02d", count.index),
#     local.vms.xcp1.tags
#   ]

#   depends_on = [xenorchestra_vm.opnsense]

#   provisioner "remote-exec" {
#     connection {
#       type     = "ssh"
#       port     = "2201"
#       user     = "root"
#       password = local.vms.xcp1.cloud_init.cloud_config.new_root_password
#       host     = tostring(xenorchestra_vm.opnsense[count.index].network[1].ipv4_addresses[0])
#       timeout  = "15m" # Allow ample time for template-xcp-ng installation and service startup
#     }
#     inline = [
#       "echo 'Waiting for xcp-ng host XAPI service to be fully up...'",
#       "max_attempts=420", # 420 attempts * 10 seconds/attempt = 4200 seconds (70 minutes)
#       "current_attempt=0",
#       "while [ $current_attempt -lt $max_attempts ]; do",
#       "  current_attempt=$((current_attempt+1))",
#       "  echo \"Attempt $current_attempt of $max_attempts: Checking xapi service...\"",
#       "  # Check if the 'xapi' (XenAPI) service is active on xcp-ng",
#       "  if systemctl is-active --quiet xapi; then",
#       "    echo 'xcp-ng xapi service is active. The xcp-ng host has booted correctly.'",
#       "    exit 0", # Success, exit the provisioner
#       "  fi",
#       "  echo 'XAPI service not yet active. Waiting 10 seconds...'",
#       "  sleep 10",
#       "done",
#       "echo 'Error: xcp-ng xapi service did not become active within the timeout.'",
#       "exit 1" # Failure, cause the provisioner to fail
#     ]
#   }

# }