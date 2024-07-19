variable "engine_type" {
  type      = string
  default   = "cpx31"
  nullable  = false
}

variable "engine_count" {
  type      = number
  default   = 0
  nullable  = false
  validation {
    condition     = var.engine_count == 0 || var.engine_count == 1
    error_message = "engine_count must be 1 or 0"
  }
}

data "hcloud_image" "bambiengine" {
  count         = var.engine_count > 0 ? 1 : 0
  with_selector = var.engine_count > 0 ? "type=bambiengine" : null
  name          = var.engine_count > 0 ? null : "debian-12"
  most_recent   = true
}

resource "hcloud_floating_ip" "bambiengine_ip" {
  type          = "ipv4"
  name          = "engine${local.subdomain}"
  home_location = var.home_location
}

resource "hcloud_floating_ip_assignment" "bambiengine_ipa" {
  count           = var.engine_count
  floating_ip_id  = hcloud_floating_ip.bambiengine_ip.id
  server_id       = hcloud_server.bambiengine[0].id
}

resource "hetznerdns_record" "bambiengine_dns" {
  count   = var.hetznerdns_zone != null ? var.engine_count : 0
  zone_id = data.hetznerdns_zone.zone[0].id
  name    = "engine${local.subdomain}"
  value   = hcloud_floating_ip.bambiengine_ip.ip_address
  type    = "A"
  ttl     = 60
}

resource "hcloud_server" "bambiengine" {
  count       = var.engine_count
  name        = "engine${local.subdomain}"
  image       = data.hcloud_image.bambiengine[0].id
  location    = var.home_location
  server_type = var.engine_type
  ssh_keys    = data.hcloud_ssh_keys.all_keys.*.id

  user_data = templatefile(
    "user_data_engine.tftpl", {
      router_ips  = hcloud_floating_ip.bambirouter_ip,
      elk         = hcloud_floating_ip.bambielk_ip.ip_address,
      engine      = hcloud_floating_ip.bambiengine_ip.ip_address,
    }
  )
}
