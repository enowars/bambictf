terraform {
  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~> 1.55"
    }
    digitalocean = {
      source  = "digitalocean/digitalocean"
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

variable "HCLOUD_DNS_TOKEN" {
  type      = string
  nullable  = true
  sensitive = true
  default   = null
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

provider "hcloud" {
  token = var.HCLOUD_DNS_TOKEN
}

data "hcloud_zone" "zone" {
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
  count     = var.proxy_count
  image     = "ubuntu-24-04-x64"
  name      = "proxy${count.index + 1}"
  region    = "fra1"
  size      = "s-1vcpu-512mb-10gb"
  ssh_keys  = [for k in data.digitalocean_ssh_keys.keys.ssh_keys : k.id]
  user_data = templatefile("user_data_proxy.tftpl", {})
}

resource "hcloud_zone_rrset" "proxy_dns" {
  count   = var.hetznerdns_zone != null ? var.proxy_count : 0
  zone    = data.hcloud_zone.zone[0].name
  name    = "proxy${count.index + 1}${local.subdomain}"
  type    = "A"
  ttl     = 60
  records = [{ value = digitalocean_droplet.proxy[count.index].ipv4_address }]
}

resource "hcloud_zone_rrset" "proxy_rr_dns" {
  count   = var.hetznerdns_zone != null ? 1 : 0
  zone    = data.hcloud_zone.zone[0].name
  name    = "proxy${local.subdomain}"
  type    = "A"
  ttl     = 60
  records = [for d in digitalocean_droplet.proxy : { value = d.ipv4_address }]
}
