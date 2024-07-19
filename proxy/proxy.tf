terraform {
  required_providers {
    hetznerdns = {
      source  = "timohirt/hetznerdns"
      version = "2.2.0"
    }
    digitalocean = {
      source = "digitalocean/digitalocean"
      version = "2.39.2"
    }

  }
  required_version = ">= 1.0"
}

variable "DO_TOKEN" {
  type      = string
  nullable  = false
  sensitive = true
}

variable "HETZNERDNS_TOKEN" {
  type      = string
  nullable  = false
  sensitive = true
}

variable "proxy_count" {
  type    = number
  default = 1
}

variable "hetznerdns_zone" {
  type    = string
  default = null
}

variable "subdomain" {
  type    = string
  default = null
}

locals {
  subdomain = var.subdomain != null ? ".${var.subdomain}" : ""
}

provider "digitalocean" {
  token = var.DO_TOKEN
}

provider "hetznerdns" {
  apitoken = var.HETZNERDNS_TOKEN
}

data "hetznerdns_zone" "zone" {
  count = var.hetznerdns_zone != null ? 1 : 0
  name  = var.hetznerdns_zone
}

data "digitalocean_ssh_keys" "keys" {
  sort {
    key       = "name"
    direction = "asc"
  }
}

# Create a new Web Droplet in the nyc2 region
resource "digitalocean_droplet" "proxy" {
  count    = var.proxy_count
  image    = "ubuntu-24-04-x64"
  name     = "proxy${count.index + 1}"
  region   = "fra1"
  size     = "s-1vcpu-512mb-10gb"
  ssh_keys = [for k in data.digitalocean_ssh_keys.keys.ssh_keys : k.id]
  user_data = templatefile("user_data_proxy.tftpl", {})
}

resource "hetznerdns_record" "proxy_dns" {
  count   = var.proxy_count
  zone_id = data.hetznerdns_zone.zone[0].id
  name    = "proxy${count.index + 1}${local.subdomain}"
  value   = digitalocean_droplet.proxy[count.index].ipv4_address
  type    = "A"
  ttl     = 60
}

resource "hetznerdns_record" "proxy_rr_dns" {
  count   = var.proxy_count
  zone_id = data.hetznerdns_zone.zone[0].id
  name    = "proxy${local.subdomain}"
  value   = digitalocean_droplet.proxy[count.index].ipv4_address
  type    = "A"
  ttl     = 60
}
