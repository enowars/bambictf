variable "vulnbox_type" {
  type     = string
  default  = "cpx21"
  nullable = false
}

variable "vulnbox_count" {
  type     = number
  default  = 0
  nullable = false
}

data "hcloud_image" "bambivulnbox" {
  with_selector = var.vulnbox_count > 0 ? "type=bambivulnbox" : null
  name          = var.vulnbox_count > 0 ? null : "debian-12"
  most_recent   = true
}

resource "hcloud_zone_rrset" "bambivulnbox_dns" {
  provider = hcloud.dns
  count    = var.hetznerdns_zone != null ? var.vulnbox_count : 0
  zone     = data.hcloud_zone.zone[0].name
  name     = "team${count.index + 1}${local.subdomain}"
  type     = "A"
  ttl      = 60
  records  = [{ value = hcloud_server.bambivulnbox[count.index].ipv4_address }]
}

resource "hcloud_server" "bambivulnbox" {
  name        = "vulnbox${count.index + 1}${local.subdomain}"
  image       = data.hcloud_image.bambivulnbox.id
  location    = try(var.vulnbox_locations[count.index], var.home_location)
  server_type = var.vulnbox_type
  count       = var.vulnbox_count
  ssh_keys    = data.hcloud_ssh_keys.all_keys.*.id

  user_data = templatefile(
    "user_data_vulnbox.tftpl", {
      wgconf      = file("../config/export/terraform/team${count.index + 1}/game.conf"),
      index       = count.index,
      id          = "${count.index + 1}",
      router_ips  = hcloud_floating_ip.bambirouter_ip,
    }
  )
}
