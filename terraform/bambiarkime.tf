variable "arkime_type" {
  type      = string
  default   = "cpx31"
  nullable  = false
}

variable "arkime_count" {
  type      = number
  default   = 0
  nullable  = false
}

locals {
  subnet  = "192.168.2.0/24"
}

data "hcloud_image" "bambiarkime" {
  with_selector = var.arkime_count > 0 ? "type=bambiarkime" : null
  name          = var.arkime_count > 0 ? null : "debian-10"
  most_recent   = true
}

resource "hetznerdns_record" "bambarkime_dns" {
  count   = var.hetznerdns_zone != null ? var.arkime_count : 0
  zone_id = data.hetznerdns_zone.zone[0].id
  name    = "arkime${count.index + 1}${local.subdomain}"
  value   = hcloud_server.bambiarkime[count.index].ipv4_address
  type    = "A"
  ttl     = 60
}

resource "hcloud_server" "bambiarkime" {
  count       = var.arkime_count
  name        = "arkime${count.index + 1}"
  image       = data.hcloud_image.bambiarkime.id
  location    = var.home_location
  server_type = var.arkime_type
  ssh_keys    = data.hcloud_ssh_keys.all_keys.*.id

  user_data = templatefile(
    "user_data_arkime.tftpl", {
      id          = "${count.index + 1}",
      masters     = join(",", [for i in range(var.arkime_count) : cidrhost(local.subnet, i+1)]),
      seeds       = join(",", setsubtract([for i in range(var.arkime_count) : cidrhost(local.subnet, i+1)], [cidrhost(local.subnet, count.index+1)])) 
      router_ips  = hcloud_floating_ip.bambirouter_ip,
      elk         = var.elk_count > 0 ? hcloud_floating_ip.bambielk_ip[0].ip_address : "127.0.0.1",
      engine      = var.engine_count > 0 ? hcloud_floating_ip.bambiengine_ip[0].ip_address : "127.0.0.1",
    }
  )
}
