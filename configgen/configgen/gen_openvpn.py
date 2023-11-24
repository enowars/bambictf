import logging
import os
from dataclasses import dataclass
from pathlib import Path

from configgen.util import DATA_DIR, _get_team_octets, run_subprocess

logger = logging.getLogger(__file__)


@dataclass
class OpenVPNTeamConfig:
    client_key: str
    server_key: str
    client_crt: str
    server_crt: str
    ca_crt: str
    ta_key: str


def gen_openvpn(teams: int, routers: int, dns: str) -> None:
    dh = get_dh()
    for team in range(1, teams + 1):
        config = get_team_config(team)
        port = 30000 + team
        x, y = _get_team_octets(team)
        TEAM_SUBNET_PREFIX = f"10.{x}.{y}"
        server_config = f"""port {port}
local 0.0.0.0
proto udp
dev team{team}
dev-type tun

mode server
tls-server
key-direction 0
cipher AES-256-CBC
auth SHA256

topology subnet
ifconfig {TEAM_SUBNET_PREFIX}.129 255.255.255.128
push "topology subnet"
ifconfig-pool {TEAM_SUBNET_PREFIX}.130 {TEAM_SUBNET_PREFIX}.254
route-gateway {TEAM_SUBNET_PREFIX}.129
push "route-gateway {TEAM_SUBNET_PREFIX}.129"
push "route 10.0.0.0 255.0.0.0"

keepalive 10 120
persist-key
persist-tun
status /etc/openvpn/server/team{team}.log
verb 3

duplicate-cn

<ca>
{config.ca_crt}</ca>

<cert>
{config.server_crt}</cert>

<key>
{config.server_key}</key>

<tls-auth>
{config.ta_key}</tls-auth>

<dh>
{dh}</dh>
"""
        client_config = f"""proto udp
dev tun
remote router{(team - 1) % routers + 1}.{dns} {port}
resolv-retry infinite
nobind

tls-client
remote-cert-tls server
key-direction 1
cipher AES-256-CBC
auth SHA256

keepalive 10 120
verb 3
pull

<ca>
{config.ca_crt}</ca>

<tls-auth>
{config.ta_key}</tls-auth>

<cert>
{config.client_crt}</cert>

<key>
{config.client_key}</key>
"""
        # Save to disk
        Path(f"{DATA_DIR}/export/ansible/routers/openvpn/team{team}.conf").write_text(
            server_config
        )
        Path(f"{DATA_DIR}/export/portal/team{team}/client.ovpn").write_text(
            client_config
        )


def get_dh() -> str:
    dh_file = Path(f"{DATA_DIR}/openvpn/dh.pem")
    try:
        return dh_file.read_text()
    except FileNotFoundError:
        pass

    logger.debug(f"Generating {dh_file}")
    run_subprocess(["openssl", "dhparam", "-out", "dh.pem", "2048"])
    return dh_file.read_text()


def get_team_config(team: int) -> OpenVPNTeamConfig:
    files = [
        Path(f"{DATA_DIR}/openvpn/team{team}/pki/private/client.key"),
        Path(f"{DATA_DIR}/openvpn/team{team}/pki/private/server.key"),
        Path(f"{DATA_DIR}/openvpn/team{team}/pki/issued/client.crt"),
        Path(f"{DATA_DIR}/openvpn/team{team}/pki/issued/server.crt"),
        Path(f"{DATA_DIR}/openvpn/team{team}/pki/ca.crt"),
        Path(f"{DATA_DIR}/openvpn/team{team}/ta.key"),
    ]
    if all(list(map(os.path.isfile, files))):
        return OpenVPNTeamConfig(
            files[0].read_text(),
            files[1].read_text(),
            files[2].read_text(),
            files[3].read_text(),
            files[4].read_text(),
            files[5].read_text(),
        )

    # TODO clean directory (might have half-done state which makes easyrsa ask things interactively)
    logger.debug(f"Generating fresh openvpn for team{team}")
    old_cwd = os.getcwd()
    os.chdir(f"{DATA_DIR}/openvpn/team{team}")
    run_subprocess(["easyrsa", "init-pki"], "yes\n")
    run_subprocess(["easyrsa", "build-ca", "nopass"], "CA\n")
    run_subprocess(["easyrsa", "gen-req", "server", "nopass"], "server\n")
    run_subprocess(["easyrsa", "sign-req", "server", "server"], "yes\n")
    run_subprocess(["easyrsa", "gen-req", "client", "nopass"], "client\n")
    run_subprocess(["easyrsa", "sign-req", "client", "client"], "yes\n")
    run_subprocess(["openvpn", "--genkey", "secret", "ta.key"])
    os.chdir(old_cwd)
    return OpenVPNTeamConfig(
        files[0].read_text(),
        files[1].read_text(),
        files[2].read_text(),
        files[3].read_text(),
        files[4].read_text(),
        files[5].read_text(),
    )
