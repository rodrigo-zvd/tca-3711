#WAN
data "xenorchestra_network" "wan" {
  name_label = local.networks.wan.name
  pool_id    = data.xenorchestra_pool.pool.id
}

# VLAN1
resource "xenorchestra_network" "vlan_1" {
  count = local.count

  name_label = format(
    "lab%02d-%s",
    count.index,
    local.networks.vlans.vlan1.name
  )
  name_description = format(
    "%s of lab%02d - cidr %s",
    local.networks.vlans.vlan1.name,
    count.index,
    local.networks.vlans.vlan1.cidr
  )
  pool_id           = data.xenorchestra_pool.pool.id
  source_pif_device = local.networks.vlans.vlan1.source_pif_device
  vlan = tonumber(
    format(
      "%s%02d%s",
      local.networks.vlans.vlan1.id_prefix,
      count.index,
      local.networks.vlans.vlan1.id_suffix

    )
  )
}

#VLAN2
resource "xenorchestra_network" "vlan_2" {
  count = local.count

  name_label = format(
    "lab%02d-%s",
    count.index,
    local.networks.vlans.vlan2.name
  )
  name_description = format(
    "%s of lab%02d - cidr %s",
    local.networks.vlans.vlan2.name,
    count.index,
    local.networks.vlans.vlan2.cidr
  )
  pool_id           = data.xenorchestra_pool.pool.id
  source_pif_device = local.networks.vlans.vlan2.source_pif_device
  vlan = tonumber(
    format(
      "%s%02d%s",
      local.networks.vlans.vlan2.id_prefix,
      count.index,
      local.networks.vlans.vlan2.id_suffix

    )
  )
}


#VLAN3
resource "xenorchestra_network" "vlan_3" {
  count = local.count

  name_label = format(
    "lab%02d-%s",
    count.index,
    local.networks.vlans.vlan3.name
  )
  name_description = format(
    "%s of lab%02d - cidr %s",
    local.networks.vlans.vlan3.name,
    count.index,
    local.networks.vlans.vlan3.cidr
  )
  pool_id           = data.xenorchestra_pool.pool.id
  source_pif_device = local.networks.vlans.vlan3.source_pif_device
  vlan = tonumber(
    format(
      "%s%02d%s",
      local.networks.vlans.vlan3.id_prefix,
      count.index,
      local.networks.vlans.vlan3.id_suffix

    )
  )
}

#SAN
resource "xenorchestra_network" "vlan_san" {
  count = local.count

  name_label = format(
    "lab%02d-%s",
    count.index,
    local.networks.vlans.san.name
  )
  name_description = format(
    "%s of lab%02d - cidr %s",
    local.networks.vlans.san.name,
    count.index,
    local.networks.vlans.san.cidr
  )
  pool_id           = data.xenorchestra_pool.pool.id
  source_pif_device = local.networks.vlans.san.source_pif_device
  vlan = tonumber(
    format(
      "%s%02d%s",
      local.networks.vlans.san.id_prefix,
      count.index,
      local.networks.vlans.san.id_suffix

    )
  )
  mtu = local.networks.vlans.san.mtu
}