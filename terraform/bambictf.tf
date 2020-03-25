# Set the variable value in the terraform.tfvars file
# hcloud_token = "..."
variable "hcloud_token" {}

provider "hcloud" {
    token = var.hcloud_token
}

locals {
    vulnbox_count = 1
    checker_count = 1
    vulnbox_type = "cx11"
    router_type = "cx11"
    checker_type = "cx11"
}

data "hcloud_image" "router" {
    #with_selector = "type=router"
    name = "debian-10"
    most_recent   = true
}

data "hcloud_image" "vulnbox" {
    #with_selector = "type=vulnbox"
    name = "debian-10"
    most_recent   = true
}

data "hcloud_image" "checker" {
    #with_selector = "type=vulnbox"
    name = "debian-10"
    most_recent   = true
}

resource "hcloud_server" "router" {
  name        = "router"
  image       = data.hcloud_image.router.id
  location    = "fsn1"
  server_type = local.router_type
  ssh_keys = [
    hcloud_ssh_key.default.id,
    hcloud_ssh_key.lucas.id
  ]
}

resource "hcloud_server" "vulnbox" {
  name        = "vulnbox${count.index}"
  image       = data.hcloud_image.vulnbox.id
  location    = "fsn1"
  server_type = local.vulnbox_type
  ssh_keys = [
    hcloud_ssh_key.default.id,
    hcloud_ssh_key.lucas.id
  ]
  count = local.vulnbox_count
}

resource "hcloud_server" "checker" {
  name        = "checker${count.index}"
  image       = data.hcloud_image.checker.id
  location    = "fsn1"
  server_type = local.checker_type
  ssh_keys = [
    hcloud_ssh_key.default.id,
    hcloud_ssh_key.lucas.id
  ]
  count = local.checker_count
}

resource "hcloud_network" "infra" {
  name     = "infra"
  ip_range = "192.168.0.0/24"
}

resource "hcloud_network_subnet" "infrasubnet" {
  network_id   = hcloud_network.infra.id
  type         = "server"
  network_zone = "eu-central"
  ip_range     = "192.168.0.0/24"
  depends_on = [
    hcloud_network.infra
  ]
}

resource "hcloud_server_network" "router" {
  server_id  = hcloud_server.router.id
  network_id = hcloud_network.infra.id
  ip         = "192.168.0.2"
  depends_on = [
    hcloud_server.router,
    hcloud_network_subnet.infrasubnet
  ]
}

// attach the checkers to the c network
resource "hcloud_server_network" "checker" {
  server_id  = hcloud_server.checker[count.index].id
  network_id = hcloud_network.infra.id
  ip         = "192.168.0.${count.index+3}"
  depends_on = [
    hcloud_server.checker,
    hcloud_network_subnet.infrasubnet
  ]
  count = local.checker_count
}

resource "hcloud_network_route" "internal_gw_route" {
  network_id  = hcloud_network.infra.id
  // you still need to set a route on the VMs itself, so the gateway only sees traffic explicitly sent to it,
  // i.e., run "ip r add 10.0.0.0/8 via 192.168.0.1" on the VM to route only the 10.0.0.0/8 network via the router
  destination = "0.0.0.0/0"
  gateway     = "192.168.0.2"
  depends_on = [
    hcloud_network.infra
  ]
}

resource "hcloud_ssh_key" "default" {
  name = "Terraform Example"
  public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILcSk1SOPd9nzWPX5TtGhmkH07OkxObJ6USlLnSskcHM ed25519-key-20161209"
}

resource "hcloud_ssh_key" "lucas" {
  name = "lucas"
  public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIP6C4GzZdaYMAdllnnuihAGvKTzTSd0OTAlxKztVQenb openpgp:0xCBA9E0D3"
}