variable "checker_type" {
  type      = string
  default   = "cpx31"
  nullable  = false
}

variable "checker_count" {
  type      = number
  default   = 0
  nullable  = false
}

data "hcloud_image" "bambichecker" {
  with_selector = var.checker_count > 0 ? "type=bambichecker" : null
  name          = var.checker_count > 0 ? null : "debian-10"
  most_recent   = true
}

resource "hetznerdns_record" "bambchecker_dns" {
  count   = var.hetznerdns_zone != null ? var.checker_count : 0
  zone_id = data.hetznerdns_zone.zone[0].id
  name    = "checker${count.index + 1}${local.subdomain}"
  value   = hcloud_server.bambichecker[count.index].ipv4_address
  type    = "A"
  ttl     = 60
}

resource "hcloud_server" "bambichecker" {
  count       = var.checker_count
  name        = "checker${count.index + 1}"
  image       = data.hcloud_image.bambichecker.id
  location    = var.home_location
  server_type = var.checker_type
  ssh_keys    = data.hcloud_ssh_keys.all_keys.*.id

  user_data = templatefile(
    "user_data_checker.tftpl", {
      id          = "${count.index + 1}",
      router_ips  = hcloud_floating_ip.bambirouter_ip,
      elk         = var.elk_count > 0 ? hcloud_floating_ip.bambielk_ip[0].ip_address : "127.0.0.1",
      engine      = var.engine_count > 0 ? hcloud_floating_ip.bambiengine_ip[0].ip_address : "127.0.0.1",
    }
  )
}
