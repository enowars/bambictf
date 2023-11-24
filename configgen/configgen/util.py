import logging
import subprocess
from dataclasses import dataclass
from pathlib import Path
from typing import Optional, Tuple

logger = logging.getLogger(__file__)
DATA_DIR = Path("../config")
CIDR_GAME = "10.0.0.0/8"
CIDR_ENGINE = "192.168.1.0/32"
CIDR_ELK = "192.168.3.0/32"
TEAM_IP_PREFIX_TEMPLATE = "10.%d.%d."
TEAM_IP_SUBNET = "/24"
TEAM_IP_WG_SUBNET = "/25"
WG_LISTEN_PORT_GAME = 51820
WG_LISTEN_PORT_INTERNAL = 51821


@dataclass
class Peer:
    public_key: str
    allowed_ips: list[str]
    endpoint: Optional[str]
    comment: Optional[str]


@dataclass
class WireguardConfig:
    private_key: str
    public_key: str
    cidr: str
    peers: list[Peer]
    listen_port: Optional[int]


@dataclass
class WireguardArkimeConfig(WireguardConfig):
    arkime_id: int


@dataclass
class WireguardRouterConfig(WireguardConfig):
    router_id: int
    responsible_ips: list[str]


@dataclass
class WireguardTeamConfig(WireguardConfig):
    team_id: int


@dataclass
class WireguardCheckerConfig(WireguardConfig):
    checker_id: int


def run_subprocess(args: list[str], input: Optional[str] = None) -> bytes:
    if input:
        bytes_input = input.encode()
    else:
        bytes_input = None
    result = subprocess.run(
        args, stderr=subprocess.PIPE, stdout=subprocess.PIPE, input=bytes_input
    )
    if result.returncode != 0:
        raise Exception(f"{args} returned {result.returncode}")
    return result.stdout


def exec_openvpn_genkey_secret() -> str:
    return run_subprocess(["openvpn", "--genkey", "secret"]).strip().decode()


def exec_wg_priv() -> str:
    return run_subprocess(["wg", "genkey"]).strip().decode()


def exec_wg_pub(priv: str) -> str:
    return run_subprocess(["wg", "pubkey"], input=priv).strip().decode()


def create_config_file(config: WireguardConfig) -> str:
    sections = [create_interface_section(config)]
    for peer in config.peers:
        sections.append(create_peer_section(peer))
    return "\n".join(sections)


def create_interface_section(config: WireguardConfig) -> str:
    raw = f"""[Interface]
Address = {config.cidr}
PrivateKey = {config.private_key}
"""
    if config.listen_port is not None:
        raw += f"ListenPort = {config.listen_port}\n"
    return raw


def create_peer_section(peer: Peer) -> str:
    allowed_ips = ", ".join(peer.allowed_ips)
    raw = ""
    if peer.comment:
        raw += f"# {peer.comment}\n"
    raw += f"""[Peer]
PublicKey = {peer.public_key}
AllowedIPs = {allowed_ips}
"""
    if peer.endpoint is not None:
        raw += f"""PersistentKeepalive = 15
Endpoint = {peer.endpoint}
"""
    return raw


def get_wg(path: Path) -> Tuple[str, str]:
    relative_path = DATA_DIR / path
    try:
        priv = relative_path.read_text()
        return priv, exec_wg_pub(priv)
    except FileNotFoundError:
        pass

    logger.debug(f"Generating fresh privkey for {path}")
    priv = exec_wg_priv()
    relative_path.write_text(priv)
    return priv, exec_wg_pub(priv)


def _get_team_octets(team_id: int) -> Tuple[int, int]:
    return (team_id // 250), (team_id % 250)


def get_vulnbox_cidr(team_id: int) -> str:
    x, y = _get_team_octets(team_id)
    return TEAM_IP_PREFIX_TEMPLATE % (x, y) + "1/32"


def get_vulnbox_ip(team_id: int) -> str:
    x, y = _get_team_octets(team_id)
    return TEAM_IP_PREFIX_TEMPLATE % (x, y) + "1"


def get_router_index(routers: int, team_id: int) -> int:
    return (team_id - 1) % routers


def get_team_cidr(team_id: int) -> str:
    x, y = _get_team_octets(team_id)
    return f"10.{x}.{y}.0/24"


def get_checker_cidr(checker_id: int) -> str:
    return f"192.168.1.{checker_id}/32"


def get_arkime_cidr(arkime_id: int) -> str:
    return f"192.168.2.{arkime_id}/32"


def get_router_cidr_game(router_id: int) -> str:
    return f"10.13.0.{router_id}/32"


def get_router_cidr_internal(router_id: int) -> str:
    return f"192.168.0.{router_id}/32"
