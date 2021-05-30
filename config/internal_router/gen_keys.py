#!/usr/bin/env python3

import os
import subprocess
import sys
from dataclasses import dataclass
from typing import List, Optional


GAME_NETWORK = "10.0.0.0/8"
TEAM_IP_PREFIX_TEMPLATE = "10.%d.%d."
TEAM_IP_SUBNET_SIZE = "/24"
INTERNAL_NETWORK = "192.168.0.0/20"
ROUTER_IP_TEMPLATE = "192.168.0.%d/32"
CHECKER_IP_TEMPLATE = "192.168.1.%d/32"
ENGINE_IP_ADDRESS = "192.168.1.0/32"
ELK_IP_ADDRESS = "192.168.3.0/32"

GATEWAY_DOMAIN_TEMPLATE = "vpn%d.bambi.ovh"
GATEWAY_LISTEN_PORT = 51821

ENGINE_DOMAIN = "engine-vpn.bambi.ovh"
ENGINE_LISTEN_PORT = 51821

ELK_DOMAIN = "elk-vpn.bambi.ovh"
ELK_LISTEN_PORT = 51821


@dataclass
class Peer:
    public_key: str
    allowed_ips: List[str]
    endpoint: Optional[str]


@dataclass
class WireguardConfig:
    private_key: str
    public_key: str
    address: str
    peers: List[Peer]
    listen_port: Optional[int]


@dataclass
class GatewayConfig(WireguardConfig):
    allowed_ips: List[str]
    domain_name: str


@dataclass
class CheckerConfig(WireguardConfig):
    pass


def gen_wireguard_keys():
    privkey_raw = subprocess.check_output(["wg", "genkey"])
    privkey = privkey_raw.strip().decode()
    result = subprocess.run(["wg", "pubkey"], stdout=subprocess.PIPE, input=privkey_raw)
    pubkey = result.stdout.strip().decode()
    return privkey, pubkey


def create_interface_section(config: WireguardConfig):
    raw = f"""[Interface]
Address = {config.address}
PrivateKey = {config.private_key}
"""
    if config.listen_port is not None:
        raw += f"ListenPort = {config.listen_port}\n"
    return raw


def create_peer_section(peer: Peer):
    allowed_ips = ", ".join(peer.allowed_ips)
    raw = f"""[Peer]
PublicKey = {peer.public_key}
AllowedIPs = {allowed_ips}
"""
    if peer.endpoint is not None:
        raw += f"""PersistentKeepalive = 15
Endpoint = {peer.endpoint}
"""
    return raw


def create_config_file(config: WireguardConfig):
    sections = [create_interface_section(config)]
    for peer in config.peers:
        sections.append(create_peer_section(peer))
    return "\n".join(sections)
    

if len(sys.argv) < 4:
    print(f"Please specify a number of teams, gateways and checkers. Usage: {sys.argv[0]} <no of teams> <no of gateways> <no of checkers>")
    sys.exit(1)

try:
    num_teams = int(sys.argv[1])
    if num_teams < 1 or num_teams > 2000:
        print("The number of teams must be between 1 and 2000.")
        sys.exit(1)
except Exception as ex:
    print(f"Could not parse number of teams: {ex}")
    sys.exit(1)

try:
    num_gateways = int(sys.argv[2])
    if num_gateways < 1 or num_gateways > num_teams or num_gateways > 250:
        print("The number of gateways must be between 1 and min(250, <no of teams>)")
        sys.exit(1)
except Exception as ex:
    print(f"Could not parse number of gateways: {ex}")
    sys.exit(1)

try:
    num_checkers = int(sys.argv[3])
    if num_checkers < 1 or num_checkers > 250:
        print("The number of checkers must be between 1 and 250")
        sys.exit(1)
except Exception as ex:
    print(f"Could not parse number of gateways: {ex}")
    sys.exit(1)

gateway_configs: List[GatewayConfig] = list()
for i in range(num_gateways):
    wg_privkey, wg_pubkey = gen_wireguard_keys()
    local_ip = ROUTER_IP_TEMPLATE % (i + 1)
    gateway_configs.append(GatewayConfig(
        private_key=wg_privkey,
        public_key=wg_pubkey,
        address=local_ip,
        allowed_ips=[local_ip],
        domain_name=GATEWAY_DOMAIN_TEMPLATE % (i + 1),
        peers=[],
        listen_port=GATEWAY_LISTEN_PORT,
    ))

elk_privkey, elk_pubkey = gen_wireguard_keys()
elk_config = GatewayConfig(
    private_key=elk_privkey,
    public_key=elk_pubkey,
    address=ELK_IP_ADDRESS,
    allowed_ips=[ELK_IP_ADDRESS],
    domain_name=ELK_DOMAIN,
    peers=[],
    listen_port=ELK_LISTEN_PORT,
)
elk_peer = Peer(
    public_key=elk_pubkey,
    allowed_ips=[ELK_IP_ADDRESS],
    endpoint=f"{ELK_DOMAIN}:{ELK_LISTEN_PORT}",
)

engine_privkey, engine_pubkey = gen_wireguard_keys()
engine_config = GatewayConfig(
    private_key=engine_privkey,
    public_key=engine_pubkey,
    address=ENGINE_IP_ADDRESS,
    allowed_ips=[ENGINE_IP_ADDRESS],
    domain_name=ENGINE_DOMAIN,
    peers=[],
    listen_port=ENGINE_LISTEN_PORT,
)
engine_peer = Peer(
    public_key=engine_pubkey,
    allowed_ips=[ENGINE_IP_ADDRESS],
    endpoint=f"{ENGINE_DOMAIN}:{ENGINE_LISTEN_PORT}",
)

elk_config.peers.append(engine_peer)
engine_config.peers.append(elk_peer)

gateway_configs: List[GatewayConfig] = list()
for i in range(num_gateways):
    wg_privkey, wg_pubkey = gen_wireguard_keys()
    local_ip = ROUTER_IP_TEMPLATE % (i + 1)
    gateway_configs.append(GatewayConfig(
        private_key=wg_privkey,
        public_key=wg_pubkey,
        address=local_ip,
        allowed_ips=[local_ip],
        domain_name=GATEWAY_DOMAIN_TEMPLATE % (i + 1),
        # don't use elk_peer and engine_peer, as those include the endpoint
        # this will cause trouble when starting the gateway before the rest
        peers=[
            Peer(
                public_key=elk_pubkey,
                allowed_ips=[ELK_IP_ADDRESS],
                endpoint=None,
            ),
            Peer(
                public_key=engine_pubkey,
                allowed_ips=[ENGINE_IP_ADDRESS],
                endpoint=None,
            ),
        ],
        listen_port=GATEWAY_LISTEN_PORT,
    ))

# add team subnets to allowed ips for the gateways
for i in range(num_teams):
    x, y = (i // 250) + 1, (i % 250) + 1
    gateway_id = i % num_gateways
    gateway_config = gateway_configs[gateway_id]
    gateway_config.allowed_ips.append(TEAM_IP_PREFIX_TEMPLATE % (x, y) + "0" + TEAM_IP_SUBNET_SIZE)

checker_peer_list: List[Peer] = [
    elk_peer,
    engine_peer,
]

for i in range(num_gateways):
    gateway_config = gateway_configs[i]
    gw_peer = Peer(
        public_key=gateway_config.public_key,
        allowed_ips=gateway_config.allowed_ips,
        endpoint=f"{gateway_config.domain_name}:{gateway_config.listen_port}",
    )
    elk_config.peers.append(gw_peer)
    engine_config.peers.append(gw_peer)
    checker_peer_list.append(gw_peer)

checker_configs = list()
for i in range(num_checkers):
    wg_privkey, wg_pubkey = gen_wireguard_keys()
    local_ip = CHECKER_IP_TEMPLATE % (i + 1)
    checker_config = CheckerConfig(
        private_key=wg_privkey,
        public_key=wg_pubkey,
        address=local_ip,
        peers=checker_peer_list,
        listen_port=None,
    )
    checker_peer = Peer(
        public_key=wg_pubkey,
        allowed_ips=[local_ip],
        endpoint=None,
    )
    elk_config.peers.append(checker_peer)
    engine_config.peers.append(checker_peer)
    for gateway_config in gateway_configs:
        gateway_config.peers.append(checker_peer)
    checker_configs.append(checker_config)

try:
    os.mkdir("gateway_configs")
except FileExistsError:
    pass

try:
    os.mkdir("checker_configs")
except FileExistsError:
    pass

# generate the config files
for i in range(num_gateways):
    with open(os.path.join("gateway_configs", f"gateway{i + 1}.conf"), "w") as f:
        f.write(create_config_file(gateway_configs[i]))

for i in range(num_checkers):
    with open(os.path.join("checker_configs", f"checker{i + 1}.conf"), "w") as f:
        f.write(create_config_file(checker_configs[i]))

with open("elk.conf", "w") as f:
    f.write(create_config_file(elk_config))

with open("engine.conf", "w") as f:
    f.write(create_config_file(engine_config))

