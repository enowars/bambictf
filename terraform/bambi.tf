terraform {
  required_providers {
    hcloud = {
      source                = "hetznercloud/hcloud"
      version               = "~> 1.55"
      configuration_aliases = [hcloud.dns]
    }
  }
  required_version = ">= 1.0"
}

variable "HCLOUD_TOKEN" {
  type      = string
  nullable  = false
  sensitive = true
}

variable "HCLOUD_DNS_TOKEN" {
  type      = string
  sensitive = true
  default   = null
}

variable "home_location" {
  type     = string
  nullable = false
  default  = "fsn1"
}

variable "hetznerdns_zone" {
  type    = string
  default = null
}

variable "subdomain" {
  type    = string
  default = null
}


variable "router_locations" {
  type = map(string)
}

variable "checker_locations" {
  type = map(string)
}

variable "engine_locations" {
  type = map(string)
}

variable "elk_locations" {
  type = map(string)
}

variable "vulnbox_locations" {
  type = map(string)
}

locals {
  subdomain = var.subdomain != null ? ".${var.subdomain}" : ""
}

provider "hcloud" {
  token = var.HCLOUD_TOKEN
}

provider "hcloud" {
  alias = "dns"
  token = coalesce(var.HCLOUD_DNS_TOKEN, var.HCLOUD_TOKEN)
}

data "hcloud_zone" "zone" {
  provider = hcloud.dns
  count    = var.hetznerdns_zone != null ? 1 : 0
  name     = var.hetznerdns_zone
}

data "hcloud_ssh_keys" "all_keys" {
  with_selector = "type=admin"
}
