resource "local_file" "ansible_inventory" {
  content = templatefile("inventory.tmpl", {
    xenorchestra = {
        name = "xenorchestra",
        ip   = xenorchestra_vm.xenorchestra.ipv4_addresses[0],
        user = local.vms.xenorchestra.cloud_init.cloud_config.user,
        uuid = xenorchestra_vm.xenorchestra.id
    }
  })

  filename        = "inventory.ini"
  file_permission = "0600"
}
