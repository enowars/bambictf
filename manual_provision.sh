#!/bin/bash

packer build ./vulnbox.json

# NOTE: This will only work with Virtualbox
VBoxManage import ./output-virtualbox-iso/vulnbox.ova
VBoxManage modifyvm "vulnbox" --natpf1 "guestssh,tcp,,2222,,22"
VBoxManage startvm "vulnbox" --type headless

ansible-playbook ansible/vulnbox.yml