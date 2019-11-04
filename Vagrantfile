# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
    config.vm.box = "debian/buster64"
    config.vm.boot_timeout = 600
    config.vm.box_check_update = false
    max_team_id = 20
    local_min_team_id = 1
    local_max_team_id = 2
    teamids = (1..max_team_id)
    local_team_ids = (local_min_team_id..local_max_team_id)

    # Ansible Variables
    host_vars = {
        "gameservers" => ["gameserver"]
    }
    extra_vars = {
        "teams" => {
            "min" => 1,
            "max" => max_team_id,
            "range" => teamids.to_a,
        }
    }
    teamids.each do |i| 
        host_vars["vulnbox#{i}"] = {
            "id" =>  i
        }
    end

    # Gameserver
    if local_min_team_id == 1
        config.vm.define "gameserver" do |gameserver|
            gameserver.vm.hostname = "gameserver"
            gameserver.vm.synced_folder './', '/vagrant', disabled: true
            gameserver.vm.provider "libvirt" do |v|
                v.memory = 6144
                v.cpus = 4
            end
            gameserver.vm.provision :ansible do |ansible|
                # Disable default limit to connect to all the machines
                ansible.limit = "all"
                ansible.host_vars = host_vars
                ansible.extra_vars = extra_vars
                ansible.playbook = "ansible/bambiserver.yml"
                #ansible.ask_vault_pass = true
            end
        end
    end

    # Vulnboxes
    local_team_ids.each do |i|
        config.vm.define "vulnbox#{i}" do |node|
            node.vm.hostname = "vulnbox#{i}"
            node.vm.synced_folder './', '/vagrant', disabled: true
            node.vm.provider "libvirt" do |v|
                v.memory = 4096
                v.cpus = 2
                v.management_network_mode = "open"
            end
            if i == local_max_team_id
                node.vm.provision :ansible do |ansible|
                    # Disable default limit to connect to all the machines
                    ansible.limit = "all"
                    ansible.host_vars = host_vars
                    ansible.extra_vars = extra_vars
                    ansible.playbook = "ansible/bambivulnbox.yml"
                    #ansible.ask_vault_pass = true
                end
            end
        end
    end
end
