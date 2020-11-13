# Set the variable value in the terraform.tfvars file
# hcloud_token = "..."
variable "hcloud_token" {}
variable "ovh_dyndns_password" {}

provider "hcloud" {
  token = var.hcloud_token
}

locals {
  vulnbox_count = 2
  checker_count = 1
  engine_count  = 1 # must be 0 or 1
  moloch_count  = 0
  elk_count     = 1
  vulnbox_type  = "cpx21"
  router_type   = "cpx21"
  checker_type  = "cpx21"
  engine_type   = "cpx21"
  moloch_type   = "cpx21"
  elk_type      = "cpx21"

  ovh_dyndns_username = "bambi.ovh-enoblade1"
  ovh_dyndns_password = var.ovh_dyndns_password
  ovh_dyndns_domain   = "bambi.ovh"

  location = "fsn1"
}

data "hcloud_ssh_keys" "all_keys" {
  with_selector = "admin=true"
}

data "hcloud_image" "bambirouter" {
  with_selector = "type=bambirouter"
  most_recent   = true
}

data "hcloud_image" "bambivulnbox" {
  with_selector = local.vulnbox_count > 0 ? "type=bambivulnbox" : null
  name          = local.vulnbox_count > 0 ? null : "debian-10"
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

data "hcloud_image" "bambimoloch" {
  with_selector = local.moloch_count > 0 ? "type=bambimoloch" : null
  name          = local.moloch_count > 0 ? null : "debian-10"
  most_recent   = true
}

data "hcloud_image" "bambielk" {
  with_selector = local.elk_count > 0 ? "type=bambielk" : null
  name          = local.elk_count > 0 ? null : "debian-10"
  most_recent   = true
}

data "hcloud_floating_ip" "vpn" {
  with_selector = "type=vpn"
}

resource "hcloud_server" "router" {
  name        = "router"
  image       = data.hcloud_image.bambirouter.id
  location    = local.location
  server_type = local.router_type

  ssh_keys = data.hcloud_ssh_keys.all_keys.*.id

  provisioner "local-exec" {
    command = "curl --user \"${local.ovh_dyndns_username}:${var.ovh_dyndns_password}\" \"https://www.ovh.com/nic/update?system=dyndns&hostname=${self.name}.${local.ovh_dyndns_domain}&myip=${self.ipv4_address}\""
  }

  user_data = <<TERRAFORMEOF
#!/bin/bash

cat > /etc/netplan/60-floating-ip.yaml <<EOF
network:
  version: 2
  ethernets:
    eth0:
      addresses:
      - ${data.hcloud_floating_ip.vpn.ip_address}/32
EOF
ip addr add ${data.hcloud_floating_ip.vpn.ip_address}/32 dev eth0

#!/bin/sh
cat <<EOF >> /etc/wireguard/internal.conf
${file("../config/internal_router/router.conf")}
EOF
systemctl enable wg-quick@internal
systemctl start wg-quick@internal

#!/bin/sh
cat <<EOF >> /etc/wireguard/router.conf
${file("../config/wireguard_router/router.conf")}
EOF
systemctl enable wg-quick@router
systemctl start wg-quick@router

cat <<EOF >> /pcaps/moloch_key
${file("../config/moloch_keys/moloch_key")}
EOF
chown -R tcpdump:tcpdump /pcaps
chmod 600 /pcaps/moloch_key
TERRAFORMEOF
}

resource "hcloud_floating_ip_assignment" "vpn" {
  floating_ip_id = data.hcloud_floating_ip.vpn.id
  server_id      = hcloud_server.router.id
}

resource "hcloud_server" "vulnbox" {
  name        = "team${count.index + 1}"
  image       = data.hcloud_image.bambivulnbox.id
  location    = local.location
  server_type = local.vulnbox_type
  count       = local.vulnbox_count

  ssh_keys = data.hcloud_ssh_keys.all_keys.*.id

  provisioner "local-exec" {
    command = "curl --user \"${local.ovh_dyndns_username}:${var.ovh_dyndns_password}\" \"https://www.ovh.com/nic/update?system=dyndns&hostname=${self.name}.ext.${local.ovh_dyndns_domain}&myip=${self.ipv4_address}\""
  }

  user_data = <<TERRAFORMEOF
#!/bin/sh
cat <<EOF >> /root/.ssh/authorized_keys
${file("../config/keys/team${count.index + 1}.keys")}
EOF
cat <<EOF >> /etc/wireguard/game.conf
${file("../config/wireguard_router/clients/team${count.index + 1}.conf")}
EOF
systemctl enable wg-quick@game
systemctl start wg-quick@game
# provision OpenVPN server for team access
/opt/setup-team-openvpn.sh

for service in $(ls /services/); do
cd "/services/$service" && docker-compose up -d &
done

cat <<EOF | passwd
${trimspace(file("../config/passwords/team${count.index + 1}.txt"))}
${trimspace(file("../config/passwords/team${count.index + 1}.txt"))}
EOF
TERRAFORMEOF
}

resource "hcloud_server" "checker" {
  name        = "checker${count.index + 1}"
  image       = data.hcloud_image.bambichecker.id
  location    = local.location
  server_type = local.checker_type
  count       = local.checker_count

  ssh_keys = data.hcloud_ssh_keys.all_keys.*.id

  provisioner "local-exec" {
    command = "curl --user \"${local.ovh_dyndns_username}:${var.ovh_dyndns_password}\" \"https://www.ovh.com/nic/update?system=dyndns&hostname=${self.name}.${local.ovh_dyndns_domain}&myip=${self.ipv4_address}\""
  }

  # ensure that the wireguard endpoint is resolved correctly on boot
  depends_on = [
    hcloud_floating_ip.engine_vpn,
    hcloud_floating_ip.elk_vpn,
  ]

  user_data = <<TERRAFORMEOF
#!/bin/sh
cat <<EOF >> /etc/wireguard/internal.conf
${file("../config/internal_router/clients/checker${count.index + 1}.conf")}
EOF
systemctl enable wg-quick@internal
systemctl start wg-quick@internal
TERRAFORMEOF
}

resource "hcloud_server" "engine" {
  name        = "engine"
  image       = data.hcloud_image.bambiengine.id
  location    = local.location
  server_type = local.engine_type
  count       = local.engine_count

  ssh_keys = data.hcloud_ssh_keys.all_keys.*.id

  provisioner "local-exec" {
    command = "curl --user \"${local.ovh_dyndns_username}:${var.ovh_dyndns_password}\" \"https://www.ovh.com/nic/update?system=dyndns&hostname=${self.name}.${local.ovh_dyndns_domain}&myip=${self.ipv4_address}\""
  }

  # ensure that the wireguard endpoint is resolved correctly on boot
  depends_on = [
    hcloud_floating_ip.elk_vpn,
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

resource "hcloud_server" "moloch" {
  name        = "moloch"
  image       = data.hcloud_image.bambimoloch.id
  location    = local.location
  server_type = local.moloch_type
  count       = local.moloch_count

  ssh_keys = data.hcloud_ssh_keys.all_keys.*.id

  provisioner "local-exec" {
    command = "curl --user \"${local.ovh_dyndns_username}:${var.ovh_dyndns_password}\" \"https://www.ovh.com/nic/update?system=dyndns&hostname=${self.name}.${local.ovh_dyndns_domain}&myip=${self.ipv4_address}\""
  }

  user_data = <<TERRAFORMEOF
#!/bin/sh
cat <<EOF >> /etc/wireguard/internal.conf
${file("../config/internal_router/moloch.conf")}
EOF
systemctl enable wg-quick@internal
systemctl start wg-quick@internal
cat <<EOF >> /root/.ssh/authorized_keys
${file("../config/moloch_keys/moloch_key.pub")}
EOF

TERRAFORMEOF
}

resource "hcloud_server" "elk" {
  name        = "elk"
  image       = data.hcloud_image.bambielk.id
  location    = local.location
  server_type = local.elk_type
  count       = local.elk_count

  ssh_keys = data.hcloud_ssh_keys.all_keys.*.id

  provisioner "local-exec" {
    command = "curl --user \"${local.ovh_dyndns_username}:${var.ovh_dyndns_password}\" \"https://www.ovh.com/nic/update?system=dyndns&hostname=${self.name}.${local.ovh_dyndns_domain}&myip=${self.ipv4_address}\""
  }

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
  count         = local.engine_count
  name          = "engine-vpn"
  type          = "ipv4"
  home_location = local.location

  provisioner "local-exec" {
    command = "curl --user \"${local.ovh_dyndns_username}:${var.ovh_dyndns_password}\" \"https://www.ovh.com/nic/update?system=dyndns&hostname=${self.name}.${local.ovh_dyndns_domain}&myip=${self.ip_address}\""
  }
}

resource "hcloud_floating_ip_assignment" "engine_vpn" {
  count          = local.engine_count
  floating_ip_id = hcloud_floating_ip.engine_vpn[0].id
  server_id      = hcloud_server.engine[0].id
}

resource "hcloud_floating_ip" "elk_vpn" {
  count         = local.elk_count
  name          = "elk-vpn"
  type          = "ipv4"
  home_location = local.location

  provisioner "local-exec" {
    command = "curl --user \"${local.ovh_dyndns_username}:${var.ovh_dyndns_password}\" \"https://www.ovh.com/nic/update?system=dyndns&hostname=${self.name}.${local.ovh_dyndns_domain}&myip=${self.ip_address}\""
  }
}

resource "hcloud_floating_ip_assignment" "elk_vpn" {
  count          = local.elk_count
  floating_ip_id = hcloud_floating_ip.elk_vpn[0].id
  server_id      = hcloud_server.elk[0].id
}
