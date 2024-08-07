import logging
from pathlib import Path

from configgen.util import (
    CIDR_ELK,
    CIDR_ENGINE,
    DATA_DIR,
    WG_LISTEN_PORT_INTERNAL,
    Peer,
    WireguardCheckerConfig,
    WireguardConfig,
    WireguardRouterConfig,
    create_config_file,
    get_checker_cidr,
    get_router_cidr_internal,
    get_router_index,
    get_team_cidr,
    get_wg,
)

logger = logging.getLogger(__file__)


def gen_wireguard_internal(teams: int, checkers: int, routers: int) -> None:
    """
    Generates the internal wireguard config files as needed, reusing keys (if present)
    """
    engine_privkey, engine_pubkey = get_wg(Path("wg_internal/engine.key"))
    engine_config = WireguardConfig(
        private_key=engine_privkey,
        public_key=engine_pubkey,
        cidr=CIDR_ENGINE,
        peers=[],
        listen_port=WG_LISTEN_PORT_INTERNAL,
    )
    engine_peer = Peer(
        public_key=engine_pubkey,
        allowed_ips=[CIDR_ENGINE],
        endpoint=f"[[ENGINE_ADDRESS]]:{WG_LISTEN_PORT_INTERNAL}",
        comment="engine",
    )

    elk_privkey, elk_pubkey = get_wg(Path("wg_internal/elk.key"))
    elk_config = WireguardConfig(
        private_key=elk_privkey,
        public_key=elk_pubkey,
        cidr=CIDR_ELK,
        peers=[],
        listen_port=WG_LISTEN_PORT_INTERNAL,
    )
    elk_peer = Peer(
        public_key=elk_pubkey,
        allowed_ips=[CIDR_ELK],
        endpoint=f"[[ELK_ADDRESS]]:{WG_LISTEN_PORT_INTERNAL}",
        comment="elk",
    )

    elk_config.peers.append(engine_peer)
    engine_config.peers.append(elk_peer)
    router_configs: list[WireguardRouterConfig] = []
    checker_configs: list[WireguardCheckerConfig] = []
    checker_peer_list: list[Peer] = [elk_peer, engine_peer]
    for router_id in range(1, routers + 1):
        local_cidr = get_router_cidr_internal(router_id)
        private_key, public_key = get_wg(Path(f"wg_internal/router{router_id}.key"))
        router_configs.append(
            WireguardRouterConfig(
                router_id=router_id,
                private_key=private_key,
                public_key=public_key,
                cidr=local_cidr,
                responsible_ips=[local_cidr],
                peers=[engine_peer, elk_peer],
                listen_port=WG_LISTEN_PORT_INTERNAL,
            )
        )

    # Route traffic to teams through the correct router
    for team in range(1, teams + 1):
        router_config = router_configs[get_router_index(routers, team)]
        router_config.responsible_ips.append(get_team_cidr(team))

    # Add router peers to elk, engine and checkers
    for router_config in router_configs:
        peer = Peer(
            public_key=router_config.public_key,
            allowed_ips=router_config.responsible_ips,
            endpoint=f"[[ROUTER_ADDRESS_{router_config.router_id}]]:{WG_LISTEN_PORT_INTERNAL}",
            comment=f"router{router_config.router_id}",
        )
        elk_config.peers.append(peer)
        engine_config.peers.append(peer)
        checker_peer_list.append(peer)

    for checker in range(1, checkers + 1):
        private_key, public_key = get_wg(Path(f"wg_internal/checker{checker}.key"))
        checker_cidr = get_checker_cidr(checker)
        checker_config = WireguardCheckerConfig(
            checker_id=checker,
            private_key=private_key,
            public_key=public_key,
            cidr=checker_cidr,
            peers=checker_peer_list,
            listen_port=None,
        )
        checker_peer = Peer(
            public_key=public_key,
            allowed_ips=[checker_cidr],
            endpoint=None,
            comment=f"checker{checker}",
        )
        elk_config.peers.append(checker_peer)
        engine_config.peers.append(checker_peer)
        for router_config in router_configs:
            router_config.peers.append(checker_peer)
        checker_configs.append(checker_config)

    # Add internal router peers
    for i in range(routers):
        for j in range(routers):
            if i == j:
                continue
            router_i = router_configs[i]
            router_j = router_configs[j]
            router_i.peers.append(
                Peer(
                    public_key=router_j.public_key,
                    allowed_ips=[get_router_cidr_internal(j+1)],
                    endpoint=f"[[ROUTER_ADDRESS_{router_j.router_id}]]:{WG_LISTEN_PORT_INTERNAL}",
                    comment=f"router{router_j.router_id}",
                )
            )

    # Save all to disk
    for router_config in router_configs:
        Path(
            f"{DATA_DIR}/export/ansible/routers/router{router_config.router_id}_internal.conf"
        ).write_text(create_config_file(router_config))

    for checker_config in checker_configs:
        Path(
            f"{DATA_DIR}/export/ansible/checkers/checker{checker_config.checker_id}.conf"
        ).write_text(create_config_file(checker_config))

    Path(f"{DATA_DIR}/export/ansible/engine/internal.conf").write_text(
        create_config_file(engine_config)
    )
    Path(f"{DATA_DIR}/export/ansible/elk/internal.conf").write_text(
        create_config_file(elk_config)
    )
