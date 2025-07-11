data "xenorchestra_pool" "pool" {
  name_label = local.pool.name
}

data "xenorchestra_sr" "sr" {
  name_label = local.pool.sr
  pool_id    = data.xenorchestra_pool.pool.id
}