# Bambi CTF Infrastructure

This is the setup used in our BambiCTF and ENOWARS competitions.

It uses ansible and packer to prepare images for Hetzner Cloud and terraform to create the infrastructure.

The Vagrantfile in the `ansible/` folder is used for local testing only (to ensure your ansible playbook does not contain any syntax errors before running them with packer on a paid VM).

## Related Repositories

This setup combines a lot of other services/repositories.

- Engine: [EnoEngine](https://github.com/enowars/enoengine)
- Checker Library: [enochecker](https://github.com/enowars/enochecker)
- Registration Page/Scoreboard: [EnoLandingPage](https://github.com/enowars/EnoLandingPage)
- Moloch (Traffic Analysis): [EnoMoloch](https://github.com/enoflag/EnoMoloch)
- ELK (Log Analysis): [EnoELK](https://github.com/enowars/EnoELK)

## Notable Limits
Due to implementation details, currently you have to be aware of the following limits:
- number of teams: 250
- number of routers: 255
- ...

## Usage (Docker)
- Have at least one ssh key with the label `type=admin` in your project **(HETZNER's WEBSITE)**
- Set `HCLOUD_TOKEN` and `HETZNERDNS_TOKEN`
- Create `./ansible/config_bambi.yml`
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
```
- Obtain a private ssh ed25519 key that can clone your repositories (`cp ~/.ssh/id_ed25519 .`)
- Run the container (`docker compose up -d`)
- Invoke a bash in the container (`docker compose exec bambictf bash`)
- If you use Windows: Fix the private key permissions with `chmod 400 ./id_ed25519`
- Build configs
    - `cd /bambictf/configgen`
    - `poetry install` (once)
    - `poetry run configgen --teams 4 --routers 2 --dns test.bambi.ovh`
- Ship everything to the EnoCTFPortal:
    - `cp -r ./export/portal /services/EnoCTFPortal/data/teamdata` (or whereever it is)
- Builds VMs
    - `cd /bambictf/packer`
    - `packer build bambichecker.json`
    - ...
- Note down vulnbox snapshot id, pass to EnoCTFPortal (`curl -H "Authorization: Bearer $HCLOUD_TOKEN" 'https://api.hetzner.cloud/v1/images?type=snapshot'`)
- Create `./terraform/terraform.tfvars` (see `./terraform/terraform.tfvars.sample` for reference)
- `cd /bambictf/terraform`
- `terraform init`
- `terraform apply`

## Open game network
- `iptables -A FORWARD -o router -j ACCEPT` (on *every* gateway)

## Emergency Port Forwards
`iptables -A INPUT -i internal -p tcp -m tcp --dport 5001 -j ACCEPT` on engine
```
iptables -A FORWARD -d 192.168.1.0/32 -i team+ -o internal -p tcp -m tcp --dport 5001 -j ACCEPT
iptables -A FORWARD -d 192.168.1.0/32 -i router -o internal -p tcp -m tcp --dport 5001 -j ACCEPT
```
on every router

## Rsync stuff
- `while true; do rsync /services/data/*.json benni@bambi.enoflag.de:/services/EnoCTFPortal_bambi7/scoreboard; sleep 5; done` TODO ask Lucas about loops and stuff
