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

source "hcloud" "bambielk" {
  image                   = "ubuntu-24.04"
  location                = "fsn1"
  server_type             = "cx22"
  ssh_username            = "root"
  snapshot_name           = "bambielk-${local.snapshot_timestamp}"
  snapshot_labels = {
    type = "bambielk"
  }
  temporary_key_pair_type = "ecdsa"
}

build {
  name    = "bambielk"

  sources = [
    "source.hcloud.bambielk"
  ]

  provisioner "ansible" {
    playbook_file = "../ansible/bambielk.yml"
    host_alias    = "packer-elk"
    ansible_env_vars = [
      "ANSIBLE_PIPELINING=True"
    ]
    extra_arguments = [
      "--scp-extra-args", "'-O'"
    ]
  }
}