variable "DO_TOKEN" {
  type = string
}

variable "proxy_count" {
  type    = number
  default = 0
}

provider "digitalocean" {
  token = var.DO_TOKEN
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
