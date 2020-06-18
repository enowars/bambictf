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
  vulnbox_type  = "cpx11"
  router_type   = "cpx11"
  checker_type  = "cpx11"
  engine_type   = "cpx21"

  ovh_dyndns_username = "bambi.ovh-enoblade1"
  ovh_dyndns_password = var.ovh_dyndns_password
  ovh_dyndns_domain   = "bambi.ovh"
}

data "hcloud_ssh_keys" "all_keys" {
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

resource "hcloud_server" "router" {
  name        = "router"
  image       = data.hcloud_image.bambirouter.id
  location    = "fsn1"
  server_type = local.router_type

  ssh_keys = data.hcloud_ssh_keys.all_keys.*.id

  provisioner "local-exec" {
    command = "curl --user \"${local.ovh_dyndns_username}:${var.ovh_dyndns_password}\" \"https://www.ovh.com/nic/update?system=dyndns&hostname=${self.name}.${local.ovh_dyndns_domain}&myip=${self.ipv4_address}\""
  }
}

resource "hcloud_server" "vulnbox" {
  name        = "team${count.index + 1}"
  image       = data.hcloud_image.bambivulnbox.id
  location    = "fsn1"
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
TERRAFORMEOF
}

resource "hcloud_server" "checker" {
  name        = "checker${count.index + 1}"
  image       = data.hcloud_image.bambichecker.id
  location    = "fsn1"
  server_type = local.checker_type
  count       = local.checker_count

  ssh_keys = data.hcloud_ssh_keys.all_keys.*.id

  provisioner "local-exec" {
    command = "curl --user \"${local.ovh_dyndns_username}:${var.ovh_dyndns_password}\" \"https://www.ovh.com/nic/update?system=dyndns&hostname=${self.name}.${local.ovh_dyndns_domain}&myip=${self.ipv4_address}\""
  }
}

resource "hcloud_server" "engine" {
  name        = "engine"
  image       = data.hcloud_image.bambiengine.id
  location    = "fsn1"
  server_type = local.engine_type
  count       = local.engine_count

  ssh_keys = data.hcloud_ssh_keys.all_keys.*.id

  provisioner "local-exec" {
    command = "curl --user \"${local.ovh_dyndns_username}:${var.ovh_dyndns_password}\" \"https://www.ovh.com/nic/update?system=dyndns&hostname=${self.name}.${local.ovh_dyndns_domain}&myip=${self.ipv4_address}\""
  }
}

resource "hcloud_network" "infra" {
  name     = "infra"
  ip_range = "192.168.0.0/20"
}

resource "hcloud_network_subnet" "infrasubnet" {
  network_id   = hcloud_network.infra.id
  type         = "server"
  network_zone = "eu-central"
  ip_range     = "192.168.0.0/20"
}

resource "hcloud_server_network" "router" {
  server_id  = hcloud_server.router.id
  network_id = hcloud_network.infra.id
  ip         = "192.168.0.2"
}

// attach the checkers to the c network
resource "hcloud_server_network" "checker" {
  server_id  = hcloud_server.checker[count.index].id
  network_id = hcloud_network.infra.id
  ip         = "192.168.1.${count.index + 1}"
  count = local.checker_count
}

// attach the engine to the infra network
resource "hcloud_server_network" "engine" {
  server_id  = hcloud_server.engine[count.index].id
  network_id = hcloud_network.infra.id
  ip         = "192.168.1.0"
  count = local.engine_count
}

resource "hcloud_network_route" "internal_gw_route" {
  network_id = hcloud_network.infra.id
  // you still need to set a route on the VMs itself, so the gateway only sees traffic explicitly sent to it,
  // i.e., run "ip r add 10.0.0.0/8 via 192.168.0.1" on the VM to route only the 10.0.0.0/8 network via the router
  destination = "0.0.0.0/0"
  gateway     = "192.168.0.2"
}
