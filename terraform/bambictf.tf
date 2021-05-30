terraform {
  required_providers {
    hetznerdns = {
      source  = "timohirt/hetznerdns"
      version = "1.1.1"
    }
    hcloud = {
      source = "hetznercloud/hcloud"
    }
  }
  required_version = ">= 0.13"
}

variable "hetznerdns_token" {}
variable "hetznerdns_zone" {}
variable "hcloud_token" {}

variable "gateway_count" {}
variable "checker_count" {}
variable "engine_count" {}
variable "elk_count" {}
variable "vulnbox_count" {}

variable "gateway_type" {}
variable "checker_type" {}
variable "engine_type" {}
variable "elk_type" {}
variable "vulnbox_type" {}

variable "home_location" {}

variable "vpn_floating_ip_only" {}
variable "internal_floating_ip_only" {}

provider "hcloud" {
  token = var.hcloud_token
}

provider "hetznerdns" {
  apitoken = var.hetznerdns_token
}

data "hetznerdns_zone" "zone" {
  name = var.hetznerdns_zone
}

locals {
  internal_floating_ip_only = var.vpn_floating_ip_only || var.internal_floating_ip_only
  router_count              = var.vpn_floating_ip_only ? 0 : var.gateway_count
  checker_count             = local.internal_floating_ip_only ? 0 : var.checker_count
  engine_count              = local.internal_floating_ip_only ? 0 : var.engine_count
  engine_vpn_count          = var.vpn_floating_ip_only ? 0 : var.engine_count
  elk_count                 = local.internal_floating_ip_only ? 0 : var.elk_count
  elk_vpn_count             = var.vpn_floating_ip_only ? 0 : var.elk_count
  router_type               = var.gateway_type
  checker_type              = var.checker_type
  engine_type               = var.engine_type
  elk_type                  = var.elk_type

  # use this only when not managing vulnboxes via the EnoLandingPage
  vulnbox_count = local.internal_floating_ip_only ? 0 : var.vulnbox_count
  vulnbox_type  = var.vulnbox_type

  location = var.home_location
}

data "hcloud_ssh_keys" "all_keys" {
}

data "hcloud_image" "bambirouter" {
  with_selector = local.router_count > 0 ? "type=bambirouter" : null
  name          = local.router_count > 0 ? null : "debian-10"
  most_recent   = true
}

data "hcloud_image" "bambichecker" {
  with_selector = local.checker_count > 0 ? "type=bambichecker" : null
  name          = local.checker_count > 0 ? null : "debian-10"
  most_recent   = true
}

data "hcloud_image" "bambiengine" {
  with_selector = local.engine_count > 0 ? "type=bambiengine" : null
  name          = local.engine_count > 0 ? null : "debian-10"
  most_recent   = true
}

data "hcloud_image" "bambielk" {
  with_selector = local.elk_count > 0 ? "type=bambielk" : null
  name          = local.elk_count > 0 ? null : "debian-10"
  most_recent   = true
}

data "hcloud_image" "vulnbox" {
  with_selector = local.vulnbox_count > 0 ? "type=bambivulnbox" : null
  name          = local.vulnbox_count > 0 ? null : "debian-10"
  most_recent   = true
}

/*data "hcloud_floating_ip" "vpn" {
  count = var.gateway_count
  name = "gateway${count.index + 1}"
}*/

resource "hcloud_floating_ip" "vpn_ip" {
  count         = var.gateway_count
  type          = "ipv4"
  name          = "gateway${count.index + 1}"
  home_location = var.home_location
}

resource "hetznerdns_record" "vpn_dns" {
  count   = var.gateway_count
  zone_id = data.hetznerdns_zone.zone.id
  name    = "vpn${count.index + 1}"
  value   = hcloud_floating_ip.vpn_ip[count.index].ip_address
  type    = "A"
  ttl     = 60
}

resource "hcloud_server" "router" {
  count       = local.router_count
  name        = "router${count.index + 1}"
  image       = data.hcloud_image.bambirouter.id
  location    = local.location
  server_type = local.router_type

  ssh_keys = data.hcloud_ssh_keys.all_keys.*.id

  user_data = <<TERRAFORMEOF
#!/bin/bash

cat > /etc/netplan/60-floating-ip.yaml <<EOF
network:
  version: 2
  ethernets:
    eth0:
      addresses:
      - ${hcloud_floating_ip.vpn_ip[count.index].ip_address}/32
EOF
ip addr add ${hcloud_floating_ip.vpn_ip[count.index].ip_address}/32 dev eth0

#!/bin/sh
cat <<EOF >> /etc/wireguard/internal.conf
${file("../config/internal_router/gateway_configs/gateway${count.index + 1}.conf")}
EOF
systemctl enable wg-quick@internal
systemctl start wg-quick@internal

#!/bin/sh
cat <<EOF >> /etc/wireguard/router.conf
${file("../config/wireguard_router/gateway_configs/gateway${count.index + 1}.conf")}
EOF
systemctl enable wg-quick@router
systemctl start wg-quick@router

(
    cd /etc/openvpn/server/
    unzip /root/zips/gateway${count.index + 1}.zip
    for i in $(ls *.conf);
      do sed -i "s/local 0.0.0.0/local ${hcloud_floating_ip.vpn_ip[count.index].ip_address}/" $${i};
      name="openvpn-server@$(echo $i | sed 's/.conf//')";
      systemctl enable $name;
      systemctl start $name;
    done
)
TERRAFORMEOF
}

resource "hcloud_floating_ip_assignment" "vpn" {
  count          = local.router_count
  floating_ip_id = hcloud_floating_ip.vpn_ip[count.index].id
  server_id      = hcloud_server.router[count.index].id
}

resource "hcloud_server" "checker" {
  name        = "checker${count.index + 1}"
  image       = data.hcloud_image.bambichecker.id
  location    = local.location
  server_type = local.checker_type
  count       = local.checker_count

  ssh_keys = data.hcloud_ssh_keys.all_keys.*.id

  # ensure that the wireguard endpoint is resolved correctly on boot
  depends_on = [
    hcloud_floating_ip.engine_vpn,
    hcloud_floating_ip.elk_vpn,
    hetznerdns_record.engine_vpn_dns,
    hetznerdns_record.elk_vpn_dns,
    hcloud_floating_ip.vpn_ip,
    hetznerdns_record.vpn_dns,
  ]

  user_data = <<TERRAFORMEOF
#!/bin/sh
cat <<EOF >> /etc/wireguard/internal.conf
${file("../config/internal_router/checker_configs/checker${count.index + 1}.conf")}
EOF
systemctl enable wg-quick@internal
systemctl start wg-quick@internal
TERRAFORMEOF
}

resource "hetznerdns_record" "checker_dns" {
  count   = local.checker_count
  zone_id = data.hetznerdns_zone.zone.id
  name    = "checker${count.index + 1}"
  value   = hcloud_server.checker[count.index].ipv4_address
  type    = "A"
  ttl     = 60
}

resource "hcloud_server" "engine" {
  name        = "engine"
  image       = data.hcloud_image.bambiengine.id
  location    = local.location
  server_type = local.engine_type
  count       = local.engine_count

  ssh_keys = data.hcloud_ssh_keys.all_keys.*.id

  # ensure that the wireguard endpoint is resolved correctly on boot
  depends_on = [
    hcloud_floating_ip.elk_vpn,
    hetznerdns_record.elk_vpn_dns,
    hcloud_floating_ip.vpn_ip,
    hetznerdns_record.vpn_dns,
  ]

  user_data = <<TERRAFORMEOF
#!/bin/sh
cat > /etc/netplan/60-floating-ip.yaml <<EOF
network:
  version: 2
  ethernets:
    eth0:
      addresses:
      - ${hcloud_floating_ip.engine_vpn[0].ip_address}/32
EOF
ip addr add ${hcloud_floating_ip.engine_vpn[0].ip_address}/32 dev eth0

cat <<EOF >> /etc/wireguard/internal.conf
${file("../config/internal_router/engine.conf")}
EOF
systemctl enable wg-quick@internal
systemctl start wg-quick@internal
TERRAFORMEOF
}

resource "hcloud_server" "elk" {
  name        = "elk"
  image       = data.hcloud_image.bambielk.id
  location    = local.location
  server_type = local.elk_type
  count       = local.elk_count

  ssh_keys = data.hcloud_ssh_keys.all_keys.*.id

  user_data = <<TERRAFORMEOF
#!/bin/sh
cat > /etc/netplan/60-floating-ip.yaml <<EOF
network:
  version: 2
  ethernets:
    eth0:
      addresses:
      - ${hcloud_floating_ip.elk_vpn[0].ip_address}/32
EOF
ip addr add ${hcloud_floating_ip.elk_vpn[0].ip_address}/32 dev eth0

cat <<EOF >> /etc/wireguard/internal.conf
${file("../config/internal_router/elk.conf")}
EOF
systemctl enable wg-quick@internal
systemctl start wg-quick@internal
TERRAFORMEOF
}

resource "hcloud_floating_ip" "engine_vpn" {
  count         = local.engine_vpn_count
  name          = "engine-vpn"
  type          = "ipv4"
  home_location = local.location
}

resource "hetznerdns_record" "engine_vpn_dns" {
  count   = local.engine_vpn_count
  zone_id = data.hetznerdns_zone.zone.id
  name    = "engine-vpn"
  value   = hcloud_floating_ip.engine_vpn[count.index].ip_address
  type    = "A"
  ttl     = 60
}

resource "hcloud_floating_ip_assignment" "engine_vpn" {
  count          = local.engine_count
  floating_ip_id = hcloud_floating_ip.engine_vpn[0].id
  server_id      = hcloud_server.engine[0].id
}

resource "hcloud_floating_ip" "elk_vpn" {
  count         = local.elk_vpn_count
  name          = "elk-vpn"
  type          = "ipv4"
  home_location = local.location
}

resource "hcloud_floating_ip_assignment" "elk_vpn" {
  count          = local.elk_count
  floating_ip_id = hcloud_floating_ip.elk_vpn[0].id
  server_id      = hcloud_server.elk[0].id
}

resource "hetznerdns_record" "elk_vpn_dns" {
  count   = local.elk_vpn_count
  zone_id = data.hetznerdns_zone.zone.id
  name    = "elk-vpn"
  value   = hcloud_floating_ip.elk_vpn[count.index].ip_address
  type    = "A"
  ttl     = 60
}

resource "hcloud_server" "vulnbox" {
  name        = "vulnbox${count.index + 1}"
  image       = data.hcloud_image.vulnbox.id
  location    = local.location
  server_type = local.vulnbox_type
  count       = local.vulnbox_count

  ssh_keys = data.hcloud_ssh_keys.all_keys.*.id

  user_data = file("../config/export/team${count.index + 1}/user_data.sh")
}

resource "hetznerdns_record" "vulnbox_dns" {
  count   = local.vulnbox_count
  zone_id = data.hetznerdns_zone.zone.id
  name    = "vulnbox${count.index + 1}"
  value   = hcloud_server.vulnbox[count.index].ipv4_address
  type    = "A"
  ttl     = 60
}