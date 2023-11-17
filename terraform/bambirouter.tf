variable "router_type" {
  type      = string
  default   = "cpx31"
  nullable  = false
}

variable "router_count" {
  type      = number
  default   = 0
  nullable  = false
}

data "hcloud_image" "bambirouter" {
  with_selector = var.router_count > 0 ? "type=bambirouter" : null
  name          = var.router_count > 0 ? null : "debian-10"
  most_recent   = true
}

resource "hcloud_floating_ip" "bambirouter_ip" {
  count         = var.router_count
  type          = "ipv4"
  name          = "router${count.index + 1}"
  home_location = var.home_location
}

resource "hcloud_floating_ip_assignment" "bambirouter_ipa" {
  count          = var.router_count
  floating_ip_id = hcloud_floating_ip.bambirouter_ip[count.index].id
  server_id      = hcloud_server.bambirouter[count.index].id
}

resource "hetznerdns_record" "bambirouter_dns" {
  count   = var.router_count
  zone_id = data.hetznerdns_zone.zone[0].id
  name    = "router${count.index + 1}${local.subdomain}"
  value   = hcloud_floating_ip.bambirouter_ip[count.index].ip_address
  type    = "A"
  ttl     = 60
}

resource "hcloud_server" "bambirouter" {
  count       = var.router_count
  name        = "router${count.index + 1}"
  image       = data.hcloud_image.bambirouter.id
  location    = var.home_location
  server_type = var.router_type
  ssh_keys    = data.hcloud_ssh_keys.all_keys.*.id

  user_data = templatefile(
    "user_data_router.tftpl", {
      index       = count.index,
      id          = "${count.index + 1}",
      router_ips  = hcloud_floating_ip.bambirouter_ip,
      elk         = var.elk_count > 0 ? hcloud_floating_ip.bambielk_ip[0].ip_address : "127.0.0.1",
      engine      = var.engine_count > 0 ? hcloud_floating_ip.bambiengine_ip[0].ip_address : "127.0.0.1",
    }
  )
}
