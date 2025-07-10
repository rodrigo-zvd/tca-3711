data "xenorchestra_template" "template" {
  name_label = local.template-xcp.template
  pool_id    = data.xenorchestra_pool.pool.id
}

data "xenorchestra_network" "network-template-xcp" {
  name_label = local.template-xcp.network.vlan
  pool_id    = data.xenorchestra_pool.pool.id
}

data "xenorchestra_vdi" "cdrom-template-xcp" {
  name_label = local.template-xcp.cdrom
  pool_id    = data.xenorchestra_pool.pool.id
}

resource "xenorchestra_vm" "template-xcp" {

  #name of vm
  name_label = local.template-xcp.name

  cdrom {
    id = data.xenorchestra_vdi.cdrom-template-xcp.id
  }

  #core cpu
  cpus = local.template-xcp.cores

  #memory ram
  memory_max = local.template-xcp.memory

  #template
  template = data.xenorchestra_template.template.id

  #network of vm
  network {
    network_id = data.xenorchestra_network.network-template-xcp.id
  }

  #disk of vm
  disk {
    sr_id      = data.xenorchestra_sr.sr.id
    name_label = "xcp-disk"
    size       = local.template-xcp.disks.xvda.size
  }

  #extra configuration
  exp_nested_hvm = true

  #tags of vm
  tags = [
    local.template-xcp.tags
  ]

  # connection ssh to vm (para o template-xcp-ng recém-instalado)
  connection {
    type = "ssh"
    # O usuário SSH do template-xcp-ng é tipicamente 'root'
    user = local.template-xcp.auth.user
    # A senha do template-xcp-ng root, definida pela instalação automatizada
    password = local.template-xcp.auth.password
    # O host IP para a conexão SSH. Deve ser o IP que o template-xcp-ng obterá/configurará.
    host = local.template-xcp.network.ip
    # Aumentar o timeout para permitir a instalação completa do template-xcp-ng e a inicialização dos serviços.
    # 70 minutos (4200 segundos) é um bom ponto de partida para 30-60 minutos de instalação.
    timeout = "70m"
  }

  # --- PROVISIONERS ---

  # 1. remote-exec: Wait for template-xcp-ng (nested) XAPI service to be fully up
  # This ensures SSH is available and template-xcp-ng is initialized before proceeding
  provisioner "remote-exec" {
    connection {
      type     = "ssh"
      user     = local.template-xcp.auth.user
      password = local.template-xcp.auth.password
      # The IP to connect to for SSH. This should be the IP the template-xcp-ng VM obtains/configures itself.
      # Ensure this IP is reachable from your Terraform execution environment.
      host    = local.template-xcp.network.ip # <--- Important: VM must obtain this IP via network config or Cloud-Init
      timeout = "70m"                         # Allow ample time for template-xcp-ng installation and service startup
    }
    inline = [
      "echo 'Waiting for nested template-xcp-ng host XAPI service to be fully up...'",
      "echo 'This might take 30 to 60 minutes, depending on your automated installation ISO.'",
      "max_attempts=420", # 420 attempts * 10 seconds/attempt = 4200 seconds (70 minutes)
      "current_attempt=0",
      "while [ $current_attempt -lt $max_attempts ]; do",
      "  current_attempt=$((current_attempt+1))",
      "  echo \"Attempt $current_attempt of $max_attempts: Checking xapi service...\"",
      "  # Check if the 'xapi' (XenAPI) service is active on template-xcp-ng",
      "  if systemctl is-active --quiet xapi; then",
      "    echo 'template-xcp-ng xapi service is active. The template-xcp-ng host has booted correctly.'",
      "    exit 0", # Success, exit the provisioner
      "  fi",
      "  echo 'XAPI service not yet active. Waiting 10 seconds...'",
      "  sleep 10",
      "done",
      "echo 'Error: template-xcp-ng xapi service did not become active within the timeout (70 minutes).'",
      "exit 1" # Failure, cause the provisioner to fail
    ]
  }

  # 2. local-exec: Execute the setup-cloud-init-boot.sh script on the Terraform machine
  # This script will then SSH into the newly provisioned template-xcp-ng VM to apply the initial config.
  provisioner "local-exec" {
    # This command executes your local script.
    # We pass the VM's details as environment variables to the script.
    # The script then uses these to SSH into the VM.
    command = <<-EOT
      VM_IP="${local.template-xcp.network.ip}" VM_USER="${local.template-xcp.auth.user}" VM_PASSWORD="${local.template-xcp.auth.password}" ./setup-cloud-init-boot.sh
    EOT
    # Assuming your setup-cloud-init-boot.sh script exists at this path.
    # Make sure this path is correct for your environment.
    # You might need to adjust the command if your local script also requires SSH_KEY path etc.
  }

}


output "vm-id" {
  value = xenorchestra_vm.template-xcp.id
}