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

source "hcloud" "bambiengine" {
  image                   = "ubuntu-24.04"
  location                = "fsn1"
  server_type             = "cx22"
  ssh_username            = "root"
  snapshot_name           = "bambiengine-${local.snapshot_timestamp}"
  snapshot_labels = {
    type = "bambiengine"
  }
  temporary_key_pair_type = "ecdsa"
}

build {
  name    = "bambiengine"

  sources = [
    "source.hcloud.bambiengine"
  ]

  provisioner "ansible" {
    playbook_file = "../ansible/bambiengine.yml"
    host_alias    = "packer-engine"
    ansible_env_vars = [
      "ANSIBLE_PIPELINING=True"
    ]
    extra_arguments = [
      "--scp-extra-args", "'-O'"
    ]
  }
}