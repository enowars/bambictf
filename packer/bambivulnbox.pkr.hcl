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

source "hcloud" "bambivulnbox" {
  image                   = "ubuntu-24.04"
  location                = "fsn1"
  server_type             = "cx32"
  ssh_username            = "root"
  snapshot_name           = "bambivulnbox-${local.snapshot_timestamp}"
  snapshot_labels = {
    type = "bambivulnbox"
  }
  temporary_key_pair_type = "ecdsa"
}

build {
  name    = "bambivulnbox"

  sources = [
    "source.hcloud.bambivulnbox"
  ]

  provisioner "ansible" {
    playbook_file = "../ansible/bambivulnbox.yml"
    host_alias    = "packer-vulnbox"
    extra_arguments = [
      "--scp-extra-args", "'-O'"
    ]
    ansible_env_vars = [
      "ANSIBLE_PIPELINING=True"
    ]
  }
}