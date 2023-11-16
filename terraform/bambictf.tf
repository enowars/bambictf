terraform {
  required_providers {
    hetznerdns = {
      source  = "timohirt/hetznerdns"
      version = "2.2.0"
    }
    hcloud = {
      source = "hetznercloud/hcloud"
      version = "1.35.2"
    }
  }
  required_version = ">= 1.0"
}

variable "HETZNERDNS_TOKEN" {}
variable "hetznerdns_zone" {}
variable "hetznerdns_suffix" {}
variable "HCLOUD_TOKEN" {}

variable "router_count" {}
variable "checker_count" {}
variable "vulnbox_count" {}

variable "router_type" {}
variable "checker_type" {}
variable "engine_type" {}
variable "elk_type" {}
variable "vulnbox_type" {}

variable "home_location" {}

provider "hcloud" {
  token = var.HCLOUD_TOKEN
}

provider "hetznerdns" {
  apitoken = var.HETZNERDNS_TOKEN
}

data "hetznerdns_zone" "zone" {
  name = var.hetznerdns_zone
}

data "hcloud_image" "bambirouter" {
  with_selector = var.router_count > 0 ? "type=bambirouter" : null
  name          = var.router_count > 0 ? null : "debian-10"
  most_recent   = true
}

data "hcloud_image" "bambiengine" {
  with_selector =  "type=bambiengine"
  most_recent   = true
}

data "hcloud_image" "bambielk" {
  with_selector =  "type=bambielk"
  most_recent   = true
}

data "hcloud_image" "bambichecker" {
  with_selector = var.checker_count > 0 ? "type=bambichecker" : null
  name          = var.checker_count > 0 ? null : "debian-10"
  most_recent   = true
}

data "hcloud_image" "bambivulnbox" {
  with_selector = var.vulnbox_count > 0 ? "type=bambivulnbox" : null
  name          = var.vulnbox_count > 0 ? null : "debian-10"
  most_recent   = true
}

data "hcloud_ssh_keys" "all_keys" {
  with_selector = "type=admin"
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
  zone_id = data.hetznerdns_zone.zone.id
  name    = "router${count.index + 1}${var.hetznerdns_suffix}"
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
      elk         = hcloud_floating_ip.bambielk_ip,
      engine      = hcloud_floating_ip.bambiengine_ip,
    }
  )
}

resource "hcloud_floating_ip" "bambiengine_ip" {
  type          = "ipv4"
  name          = "engine"
  home_location = var.home_location
}

resource "hcloud_floating_ip_assignment" "bambiengine_ipa" {
  floating_ip_id = hcloud_floating_ip.bambiengine_ip.id
  server_id      = hcloud_server.bambiengine.id
}

resource "hetznerdns_record" "bambiengine_dns" {
  zone_id = data.hetznerdns_zone.zone.id
  name    = "engine${var.hetznerdns_suffix}"
  value   = hcloud_floating_ip.bambiengine_ip.ip_address
  type    = "A"
  ttl     = 60
}

resource "hcloud_server" "bambiengine" {
  name        = "bambiengine"
  image       = data.hcloud_image.bambiengine.id
  location    = var.home_location
  server_type = var.engine_type
  ssh_keys    = data.hcloud_ssh_keys.all_keys.*.id

  user_data = templatefile(
    "user_data_engine.tftpl", {
      router_ips  = hcloud_floating_ip.bambirouter_ip,
      elk         = hcloud_floating_ip.bambielk_ip,
      engine      = hcloud_floating_ip.bambiengine_ip,
    }
  )
}

resource "hetznerdns_record" "bambchecker_dns" {
  count   = var.checker_count
  zone_id = data.hetznerdns_zone.zone.id
  name    = "checker${count.index + 1}${var.hetznerdns_suffix}"
  value   = hcloud_server.bambichecker[count.index].ipv4_address
  type    = "A"
  ttl     = 60
}

resource "hcloud_server" "bambichecker" {
  name        = "bambichecker"
  image       = data.hcloud_image.bambichecker.id
  location    = var.home_location
  server_type = var.checker_type
  count       = var.checker_count
  ssh_keys    = data.hcloud_ssh_keys.all_keys.*.id

  user_data = templatefile(
    "user_data_checker.tftpl", {
      id          = "${count.index + 1}",
      router_ips  = hcloud_floating_ip.bambirouter_ip,
      elk         = hcloud_floating_ip.bambielk_ip,
      engine      = hcloud_floating_ip.bambiengine_ip,
    }
  )
}

resource "hcloud_floating_ip" "bambielk_ip" {
  type          = "ipv4"
  name          = "elk"
  home_location = var.home_location
}

resource "hcloud_floating_ip_assignment" "bambielk_ipa" {
  floating_ip_id = hcloud_floating_ip.bambielk_ip.id
  server_id      = hcloud_server.bambielk.id
}

resource "hetznerdns_record" "bambielk_dns" {
  zone_id = data.hetznerdns_zone.zone.id
  name    = "elk${var.hetznerdns_suffix}"
  value   = hcloud_server.bambielk.ipv4_address
  type    = "A"
  ttl     = 60
}

resource "hcloud_server" "bambielk" {
  name        = "bambielk"
  image       = data.hcloud_image.bambielk.id
  location    = var.home_location
  server_type = var.elk_type
  ssh_keys    = data.hcloud_ssh_keys.all_keys.*.id

  user_data = templatefile(
    "user_data_elk.tftpl", {
      router_ips  = hcloud_floating_ip.bambirouter_ip,
      elk         = hcloud_floating_ip.bambielk_ip,
      engine      = hcloud_floating_ip.bambiengine_ip,
    }
  )
}

resource "hcloud_server" "bambivulnbox" {
  name        = "vulnbox${count.index + 1}"
  image       = data.hcloud_image.bambivulnbox.id
  location    = var.home_location
  server_type = var.vulnbox_type
  count       = var.vulnbox_count
  ssh_keys    = data.hcloud_ssh_keys.all_keys.*.id

  user_data = templatefile(
    "user_data_vulnbox.tftpl", {
      wgconf      = file("../config/export/terraform/team${count.index + 1}/game.conf"),
      index       = count.index,
      id          = "${count.index + 1}",
      router_ips  = hcloud_floating_ip.bambirouter_ip
    }
  )
}

resource "hetznerdns_record" "bambivulnbox_dns" {
  count   = var.vulnbox_count
  zone_id = data.hetznerdns_zone.zone.id
  name    = "team${count.index + 1}${var.hetznerdns_suffix}"
  value   = hcloud_server.bambivulnbox[count.index].ipv4_address
  type    = "A"
  ttl     = 60
}
