Generate all the VMs

Currently Gutenberged together from: [here](https://github.com/deimosfr/packer-debian) and [here](https://github.com/geerlingguy/packer-debian-9)


# Create a new vulnbox

Needs to have `ansible` and `packer` installed on host.

* `packer build vulnbox.json`  
* Wait until done.
* Import into VBox and start
* Enable portforwarding
* `ansible-playbook ansible/vulnbox.yml`
* Wait
* ssh into vulnbox
* `network-script <teamid> <interface>`

If you use Virtualbox execute the `prep_manual_vulnbox.sh` after `packer` is done and continue with `ansible`.