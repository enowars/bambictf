# Bambi CTF Infrastructure

This is the setup used for our Bambi CTF training competitions. It was also used to host [ENOWARS4](https://enowars.com).

It uses ansible and packer to prepare images for Hetzner Cloud and terraform to create the infrastructure.

The Vagrantfile in the `ansible/` folder is used for local testing only (to ensure your ansible playbook does not contain any syntax errors before running them with packer on a paid VM).

## Related Repositories

This setup combines a lot of other services/repositories.

- Engine: [EnoEngine](https://github.com/enowars/enoengine)
- Checker Library: [enochecker](https://github.com/enowars/enochecker)
- Registration Page/Scoreboard: [EnoLandingPage](https://github.com/enowars/EnoLandingPage)
- Moloch (Traffic Analysis): [EnoMoloch](https://github.com/enoflag/EnoMoloch)
- ELK (Log Analysis): [EnoELK](https://github.com/enowars/EnoELK)

## Usage

1. Create `./ansible/config_bambi.yml`:
```yaml
vulnerable_services:
    WASP: git@github.com:enowars/service-wasp.git
    djbooth: git@github.com:enowars/service-DJ_Booth.git
    switzerland: git@github.com:enowars/service-switzerland.git
    teapot: git@github.com:enowars/service-teapot.git
github_ssh_keys:
    - Trolldemorted
    - domenukk
    - ldruschk
    - MMunier
elk_address: ip or url
moloch_internal_ip: ip or url
```
2. Create `./terraform/terraform.tfvars`:
```
hcloud_token = "..."
ovh_dyndns_password = "..."
```
3. Initialize terraform:
```
(cd terraform; terraform init)
```
4. Generate wireguard configs for the internal network
```sh
(cd ./config/internal_router; ./gen_keys.sh $CHECKERS_COUNT)
```
5. Generate wireguard configs for the game network
```sh
(cd ./config/wireguard_router; ./gen_keys.sh $TEAMS_COUNT)
```
6. Generate passwords for the vulnboxes:
```sh
(cd ./config/passwords; ./gen_passwords.sh $TEAMS_COUNT)
```
7. Create SSH keys for router -> moloch
```sh
(ssh-keygen -t ed25519 -f ./config/moloch_keys/moloch_key -C "tcpdump@router")
```
8. Build images
```sh
export HCLOUD_TOKEN="..."
(cd packer; packer build bambichecker.json)
(cd packer; packer build bambiengine.json)
(cd packer; packer build bambirouter.json)
(cd packer; packer build bambivulnbox.json)
(cd packer; packer build bambielk.json)
```

## Docker
- Have at least one ssh key with the label `type=admin` in your project
- Set `HCLOUD_TOKEN` and `HETZNERDNS_TOKEN`
- Create `./ansible/config_bambi.yml`
- Obtain a private ssh ed25519 key that can clone your repositories (`cp ~/.ssh/id_ed25519 .`)
- Run the container (`docker compose up -d`)
- Invoke a bash in the container (`docker compose exec bambictf bash`)
- Build configs
    - `cd /bambictf/config`
    - `./gen_config.sh`
- Builds VMs
    - `cd /bambictf/packer`
    - `packer build bambichecker.json`
- Create `./terraform/terraform.tfvars`
- `cd ./terraform`
- `terraform init`
- `terraform apply`


## Open game network
- `iptables -A FORWARD -o router -j ACCEPT` (on *every* gateway)


## Rsync stuff
- `while true; do rsync /services/data/*.json benni@bambi.enoflag.de:/services/EnoCTFPortal_bambi7/scoreboard; sleep 5; done` TODO ask Lucas about loops and stuff
