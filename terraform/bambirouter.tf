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

locals {
  subnet  = "192.168.0.0/24"
}

data "hcloud_image" "bambirouter" {
  with_selector = var.router_count > 0 ? "type=bambirouter" : null
  name          = var.router_count > 0 ? null : "debian-10"
  most_recent   = true
}

resource "hcloud_floating_ip" "bambirouter_ip" {
  count         = var.router_count
  type          = "ipv4"
  name          = "router${count.index + 1}${local.subdomain}"
  home_location = var.home_location
}

resource "hcloud_floating_ip_assignment" "bambirouter_ipa" {
  count          = var.router_count
  floating_ip_id = hcloud_floating_ip.bambirouter_ip[count.index].id
  server_id      = hcloud_server.bambirouter[count.index].id
}

resource "hetznerdns_record" "bambirouter_dns" {
  count   = var.hetznerdns_zone != null ? var.router_count : 0
  zone_id = data.hetznerdns_zone.zone[0].id
  name    = "router${count.index + 1}${local.subdomain}"
  value   = hcloud_floating_ip.bambirouter_ip[count.index].ip_address
  type    = "A"
  ttl     = 60
}

resource "hcloud_server" "bambirouter" {
  count       = var.router_count
  name        = "router${count.index + 1}${local.subdomain}"
  image       = data.hcloud_image.bambirouter.id
  location    = var.home_location
  server_type = var.router_type
  ssh_keys    = data.hcloud_ssh_keys.all_keys.*.id

  user_data = templatefile(
    "user_data_router.tftpl", {
      index       = count.index,
      id          = "${count.index + 1}",
      masters     = join(",", [for i in range(var.router_count) : cidrhost(local.subnet, i+1)]),
      seeds       = join(",", setsubtract([for i in range(var.router_count) : cidrhost(local.subnet, i+1)], [cidrhost(local.subnet, count.index+1)])) 
      router_ips  = hcloud_floating_ip.bambirouter_ip,
      elk         = hcloud_floating_ip.bambielk_ip.ip_address,
      engine      = hcloud_floating_ip.bambiengine_ip.ip_address,
    }
  )
}
