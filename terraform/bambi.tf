terraform {
  required_providers {
    hetznerdns = {
      source  = "timohirt/hetznerdns"
      version = "2.2.0"
    }
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "1.35.2"
    }
  }
  required_version = ">= 1.0"
}

variable "HCLOUD_TOKEN" {
  type      = string
  nullable  = false
  sensitive = true
}

variable "HETZNERDNS_TOKEN" {
  type      = string
  sensitive = true
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

locals {
  subdomain = var.subdomain != null ? ".${var.subdomain}" : ""
}

provider "hcloud" {
  token = var.HCLOUD_TOKEN
}

provider "hetznerdns" {
  apitoken = var.HETZNERDNS_TOKEN
}

data "hetznerdns_zone" "zone" {
  count = var.hetznerdns_zone != null ? 1 : 0
  name  = var.hetznerdns_zone
}

data "hcloud_ssh_keys" "all_keys" {
  with_selector = "type=admin"
}
