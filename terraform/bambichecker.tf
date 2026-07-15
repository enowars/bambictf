variable "checker_type" {
  type     = string
  default  = "cpx31"
  nullable = false
}

variable "checker_count" {
  type     = number
  default  = 0
  nullable = false
}

data "hcloud_image" "bambichecker" {
  with_selector = var.checker_count > 0 ? "type=bambichecker" : null
  name          = var.checker_count > 0 ? null : "debian-12"
  most_recent   = true
}

resource "hcloud_zone_rrset" "bambchecker_dns" {
  provider = hcloud.dns
  count    = var.hetznerdns_zone != null ? var.checker_count : 0
  zone     = data.hcloud_zone.zone[0].name
  name     = "checker${count.index + 1}${local.subdomain}"
  type     = "A"
  ttl      = 60
  records  = [{ value = hcloud_server.bambichecker[count.index].ipv4_address }]
}

resource "hcloud_server" "bambichecker" {
  count       = var.checker_count
  name        = "checker${count.index + 1}${local.subdomain}"
  image       = data.hcloud_image.bambichecker.id
  location    = try(var.checker_locations[count.index], var.home_location)
  server_type = var.checker_type
  ssh_keys    = data.hcloud_ssh_keys.all_keys.*.id

  user_data = templatefile(
    "user_data_checker.tftpl", {
      id          = "${count.index + 1}",
      router_ips  = hcloud_floating_ip.bambirouter_ip,
      elk         = hcloud_floating_ip.bambielk_ip.ip_address,
      engine      = hcloud_floating_ip.bambiengine_ip.ip_address,
    }
  )
}
