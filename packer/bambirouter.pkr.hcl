packer {
  required_plugins {
    hcloud = {
      version = ">= 1.0.0"
      source  = "github.com/hetznercloud/hcloud"
    }
  }
}

locals {
  snapshot_timestamp = timestamp()
}

source "hcloud" "bambirouter" {
  image                   = "ubuntu-24.04"
  location                = "fsn1"
  server_type             = "cx22"
  ssh_username            = "root"
  snapshot_name           = "bambirouter-${local.snapshot_timestamp}"
  snapshot_labels = {
    type = "bambirouter"
  }
  temporary_key_pair_type = "ecdsa"
}

build {
  name    = "bambirouter"

  sources = [
    "source.hcloud.bambirouter"
  ]

  provisioner "ansible" {
    playbook_file = "../ansible/bambirouter.yml"
    host_alias    = "packer-router"
    ansible_env_vars = [
      "ANSIBLE_PIPELINING=True"
    ]
    extra_arguments = [
      "--scp-extra-args", "'-O'"
    ]
  }
}