variable "arkime_type" {
  type      = string
  default   = "cpx31"
  nullable  = false
}

variable "use_arkime" {
  type      = bool
  default   = false
  nullable  = false
}

locals {
  subnet  = "192.168.2.0/24"
}

data "hcloud_image" "bambiarkime" {
  with_selector = var.use_arkime ? "type=bambiarkime" : null
  name          = var.use_arkime ? null : "debian-10"
  most_recent   = true
}

resource "hcloud_floating_ip" "bambiarkime_ip" {
  count         = var.use_arkime ? var.router_count : 0
  type          = "ipv4"
  name          = "arkime${count.index + 1}"
  home_location = var.home_location
}

resource "hcloud_floating_ip_assignment" "bambiarkime_ipa" {
  count          = var.use_arkime ? var.router_count : 0
  floating_ip_id = hcloud_floating_ip.bambiarkime_ip[count.index].id
  server_id      = hcloud_server.bambiarkime[count.index].id
}

resource "hetznerdns_record" "bambarkime_dns" {
  count   = var.hetznerdns_zone != null && var.use_arkime ? var.router_count : 0
  zone_id = data.hetznerdns_zone.zone[0].id
  name    = "arkime${count.index + 1}${local.subdomain}"
  value   = hcloud_server.bambiarkime[count.index].ipv4_address
  type    = "A"
  ttl     = 60
}

resource "hcloud_server" "bambiarkime" {
  count       = var.use_arkime ? var.router_count : 0
  name        = "arkime${count.index + 1}"
  image       = data.hcloud_image.bambiarkime.id
  location    = var.home_location
  server_type = var.arkime_type
  ssh_keys    = data.hcloud_ssh_keys.all_keys.*.id

  user_data = templatefile(
    "user_data_arkime.tftpl", {
      index       = count.index,
      id          = "${count.index + 1}",
      masters     = join(",", [for i in range(var.router_count) : cidrhost(local.subnet, i+1)]),
      seeds       = join(",", setsubtract([for i in range(var.router_count) : cidrhost(local.subnet, i+1)], [cidrhost(local.subnet, count.index+1)])) 
      router_ips  = hcloud_floating_ip.bambirouter_ip,
      elk         = var.elk_count > 0 ? hcloud_floating_ip.bambielk_ip[0].ip_address : "127.0.0.1",
      engine      = var.engine_count > 0 ? hcloud_floating_ip.bambiengine_ip[0].ip_address : "127.0.0.1",
      arkime_ips  = hcloud_floating_ip.bambiarkime_ip,
    }
  )
}
