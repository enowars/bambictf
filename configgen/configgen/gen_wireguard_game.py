import logging
from pathlib import Path
from typing import Optional

from configgen.util import (
    CIDR_GAME,
    DATA_DIR,
    TEAM_IP_PREFIX_TEMPLATE,
    TEAM_IP_SUBNET,
    TEAM_IP_WG_SUBNET,
    WG_LISTEN_PORT_GAME,
    Peer,
    WireguardRouterConfig,
    WireguardTeamConfig,
    create_config_file,
    get_router_cidr_game,
    get_team_octets,
    get_vulnbox_cidr,
    get_wg,
)

logger = logging.getLogger(__file__)


def gen_wireguard_game(teams: int, dns: Optional[str], routers: int) -> None:
    """
    Generates the game wireguard config files as needed, reusing keys (if present)
    """
    router_configs: list[WireguardRouterConfig] = []
    team_portal_configs: list[WireguardTeamConfig] = []
    team_terraform_configs: list[WireguardTeamConfig] = []

    # Generate router configs
    for router_id in range(1, routers + 1):
        local_ip = get_router_cidr_game(router_id)
        private_key, public_key = get_wg(Path(f"wg_game/router{router_id}.key"))
        router_configs.append(
            WireguardRouterConfig(
                router_id=router_id,
                private_key=private_key,
                public_key=public_key,
                cidr=local_ip,
                responsible_ips=[local_ip],
                peers=[],
                listen_port=WG_LISTEN_PORT_GAME,
            )
        )

    # Generate team configs and add the peers to router configs
    for team in range(1, teams + 1):
        private_key, public_key = get_wg(Path(f"wg_game/team{team}.key"))
        x, y = get_team_octets(team)
        router_index = (team - 1) % routers
        router_config = router_configs[router_index]
        if dns is not None:
            team_portal_configs.append(
                gen_team_config(private_key, public_key, team, router_config, dns)
            )
        team_terraform_configs.append(
            gen_team_config(private_key, public_key, team, router_config, None)
        )

        router_config.peers.append(
            Peer(
                public_key=public_key,
                allowed_ips=[
                    TEAM_IP_PREFIX_TEMPLATE % (x, y) + "0" + TEAM_IP_WG_SUBNET
                ],
                endpoint=None,
                comment=f"team{team}",
            )
        )
        router_config.responsible_ips.append(
            TEAM_IP_PREFIX_TEMPLATE % (x, y) + "0" + TEAM_IP_SUBNET
        )

    for i in range(routers):
        for j in range(routers):
            if i == j:
                continue
            router_i = router_configs[i]
            router_j = router_configs[j]
            router_i.peers.append(
                Peer(
                    public_key=router_j.public_key,
                    allowed_ips=router_j.responsible_ips,
                    endpoint=f"[[ROUTER_ADDRESS_{router_j.router_id}]]:{WG_LISTEN_PORT_GAME}",
                    comment=f"router{router_j.router_id}",
                )
            )

    if dns is not None:
        for team_portal_config in team_portal_configs:
            Path(
                f"{DATA_DIR}/export/portal/team{team_portal_config.team_id}/game.conf"
            ).write_text(create_config_file(team_portal_config))

    for team_terraform_config in team_terraform_configs:
        Path(
            f"{DATA_DIR}/export/terraform/team{team_terraform_config.team_id}/game.conf"
        ).write_text(create_config_file(team_terraform_config))

    for router_config in router_configs:
        Path(
            f"{DATA_DIR}/export/ansible/routers/router{router_config.router_id}_game.conf"
        ).write_text(create_config_file(router_config))


def gen_team_config(
    private_key: str,
    public_key: str,
    team_id: int,
    router_config: WireguardRouterConfig,
    dns_suffix: Optional[str],
) -> WireguardTeamConfig:
    if dns_suffix:
        endpoint = f"router{router_config.router_id}.{dns_suffix}:{WG_LISTEN_PORT_GAME}"
    else:
        endpoint = f"[[ROUTER_ADDRESS_{router_config.router_id}]]:{WG_LISTEN_PORT_GAME}"

    return WireguardTeamConfig(
        private_key=private_key,
        public_key=public_key,
        cidr=get_vulnbox_cidr(team_id),
        peers=[
            Peer(
                public_key=router_config.public_key,
                allowed_ips=[CIDR_GAME],
                endpoint=endpoint,
                comment=f"router{router_config.router_id}",
            )
        ],
        listen_port=None,
        team_id=team_id,
    )
