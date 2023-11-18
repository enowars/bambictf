variable "elk_type" {
  type      = string
  default   = "cpx31"
  nullable  = false
}

variable "elk_count" {
  type      = number
  default   = 0
  nullable  = false
  validation {
    condition     = var.elk_count == 0 || var.elk_count == 1
    error_message = "elk_count must be 1 or 0"
  }
}

data "hcloud_image" "bambielk" {
  count         = var.elk_count > 0 ? 1 : 0
  with_selector = var.elk_count > 0 ? "type=bambielk" : null
  name          = var.elk_count > 0 ? null : "debian-10"
  most_recent   = true
}

resource "hcloud_floating_ip" "bambielk_ip" {
  count         = var.elk_count
  type          = "ipv4"
  name          = "elk"
  home_location = var.home_location
}

resource "hcloud_floating_ip_assignment" "bambielk_ipa" {
  count           = var.elk_count
  floating_ip_id  = hcloud_floating_ip.bambielk_ip[0].id
  server_id       = hcloud_server.bambielk[0].id
}

resource "hetznerdns_record" "bambielk_dns" {
  count   = var.hetznerdns_zone != null ? var.elk_count : 0
  zone_id = data.hetznerdns_zone.zone[0].id
  name    = "elk${local.subdomain}"
  value   = hcloud_server.bambielk[0].ipv4_address
  type    = "A"
  ttl     = 60
}

resource "hcloud_server" "bambielk" {
  count       = var.elk_count
  name        = "bambielk"
  image       = data.hcloud_image.bambielk[0].id
  location    = var.home_location
  server_type = var.elk_type
  ssh_keys    = data.hcloud_ssh_keys.all_keys.*.id

  user_data = templatefile(
    "user_data_elk.tftpl", {
      router_ips  = hcloud_floating_ip.bambirouter_ip,
      elk         = var.elk_count > 0 ? hcloud_floating_ip.bambielk_ip[0].ip_address : "127.0.0.1",
      engine      = var.engine_count > 0 ? hcloud_floating_ip.bambiengine_ip[0].ip_address : "127.0.0.1",
    }
  )
}
