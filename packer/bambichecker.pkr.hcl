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

source "hcloud" "bambichecker" {
  image                   = "ubuntu-24.04"
  location                = "fsn1"
  server_type             = "cx22"
  ssh_username            = "root"
  snapshot_name           = "bambichecker-${local.snapshot_timestamp}"
  snapshot_labels = {
    type = "bambichecker"
  }
  temporary_key_pair_type = "ecdsa"
}

build {
  name    = "bambichecker"

  sources = [
    "source.hcloud.bambichecker"
  ]

  provisioner "ansible" {
    playbook_file = "../ansible/bambichecker.yml"
    host_alias    = "packer-checker"
    ansible_env_vars = [
      "ANSIBLE_PIPELINING=True"
    ]
    extra_arguments = [
      "--scp-extra-args", "'-O'"
    ]
  }
}