#!/usr/bin/env python3

import os
import subprocess
import sys
from dataclasses import dataclass
from typing import List, Optional


GAME_NETWORK = "10.0.0.0/8"
ROUTER_IP_TEMPLATE = "10.13.0.%d/32"
TEAM_IP_PREFIX_TEMPLATE = "10.%d.%d."
TEAM_IP_SUBNET_SIZE = "/24"
TEAM_IP_WG_SUBNET_SIZE = "/25"
GATEWAY_DOMAIN_TEMPLATE = "vpn%d.bambi.ovh"
GATEWAY_LISTEN_PORT = 51820


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
class TeamConfig(WireguardConfig):
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
    

if len(sys.argv) < 3:
    print(f"Please specify a number of teams and gateways. Usage: {sys.argv[0]} <no of teams> <no of gateways>")
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

team_configs = list()
for i in range(num_teams):
    wg_privkey, wg_pubkey = gen_wireguard_keys()
    x, y = (i // 250) + 1, (i % 250) + 1
    gateway_id = i % num_gateways
    gateway_config = gateway_configs[gateway_id]
    team_configs.append(TeamConfig(
        private_key=wg_privkey,
        public_key=wg_pubkey,
        address=TEAM_IP_PREFIX_TEMPLATE % (x, y) + "1/32",
        peers=[
            Peer(
                public_key=gateway_config.public_key,
                allowed_ips=[GAME_NETWORK],
                endpoint=f"{gateway_config.domain_name}:{GATEWAY_LISTEN_PORT}",
            )
        ],
        listen_port=None,
    ))
    gateway_config.peers.append(Peer(
        public_key=wg_pubkey,
        allowed_ips=[TEAM_IP_PREFIX_TEMPLATE % (x, y) + "0" + TEAM_IP_WG_SUBNET_SIZE],
        endpoint=None,
    ))
    gateway_config.allowed_ips.append(TEAM_IP_PREFIX_TEMPLATE % (x, y) + "0" + TEAM_IP_SUBNET_SIZE)

# create the peer entries for the gateways
for i in range(num_gateways):
    for j in range(num_gateways):
        if i == j:
            continue
        gateway_i = gateway_configs[i]
        gateway_j = gateway_configs[j]
        gateway_i.peers.append(Peer(
            public_key=gateway_j.public_key,
            allowed_ips=gateway_j.allowed_ips,
            endpoint=f"{gateway_j.domain_name}:{GATEWAY_LISTEN_PORT}",
        ))

try:
    os.mkdir("gateway_configs")
except FileExistsError:
    pass

try:
    os.mkdir("team_configs")
except FileExistsError:
    pass

# generate the config files
for i in range(num_gateways):
    with open(os.path.join("gateway_configs", f"gateway{i + 1}.conf"), "w") as f:
        f.write(create_config_file(gateway_configs[i]))

for i in range(num_teams):
    with open(os.path.join("team_configs", f"team{i + 1}.conf"), "w") as f:
        f.write(create_config_file(team_configs[i]))

