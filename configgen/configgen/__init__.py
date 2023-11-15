import argparse
import logging
import secrets
import shutil
from pathlib import Path

from configgen.gen_wireguard_game import gen_wireguard_game
from configgen.gen_wireguard_internal import gen_wireguard_internal
from configgen.util import DATA_DIR

logging.basicConfig(level=logging.DEBUG)
logger = logging.getLogger(__file__)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--teams", type=int, required=True)
    parser.add_argument("--dns", type=str, required=True)
    parser.add_argument("--routers", type=int, default=2)
    parser.add_argument("--checkers", type=int, default=10)
    args = parser.parse_args()
    teams: int = args.teams
    dns: str = args.dns
    routers: int = args.routers
    checkers: int = args.checkers
    logger.info(f"Generating for {teams} teams, {routers} gws and {checkers} checkers")
    prepare_directories(teams)
    gen_wireguard_game(teams, dns, routers)
    gen_wireguard_internal(teams, checkers, routers)
    gen_passwords(teams)
    gen_userdata_portal(teams)


def prepare_directories(teams: int) -> None:
    Path(f"{DATA_DIR}/passwords/").mkdir(parents=True, exist_ok=True)
    Path(f"{DATA_DIR}/wg_game/").mkdir(parents=True, exist_ok=True)
    Path(f"{DATA_DIR}/wg_internal/").mkdir(parents=True, exist_ok=True)
    shutil.rmtree(DATA_DIR / "export")
    Path(f"{DATA_DIR}/export/ansible/checkers").mkdir(parents=True, exist_ok=True)
    Path(f"{DATA_DIR}/export/ansible/routers").mkdir(parents=True, exist_ok=True)
    for team in range(1, teams + 1):
        Path(f"{DATA_DIR}/export/portal/team{team}").mkdir(parents=True, exist_ok=True)
        Path(f"{DATA_DIR}/export/terraform/team{team}").mkdir(
            parents=True, exist_ok=True
        )
    Path(f"{DATA_DIR}/export/terraform/teams").mkdir(parents=True, exist_ok=True)


def gen_userdata_portal(teams: int) -> None:
    for team in range(1, teams + 1):
        user_data = gen_userdata(team, True)
        Path(f"{DATA_DIR}/export/portal/team{team}/user_data.sh").write_text(user_data)


def gen_userdata(team: int, portal: bool) -> str:
    password = Path(f"{DATA_DIR}/export/portal/team{team}/password.txt").read_text()
    if portal:
        wg = Path(f"{DATA_DIR}/export/portal/team{team}/game.conf").read_text()
    else:
        wg = Path(f"{DATA_DIR}/export/terraform/team{team}/game.conf").read_text()
    return f"""#!/bin/sh
cat <<EOF >> /etc/wireguard/game.conf
{wg}
EOF

for service in $(ls /services/); do
    cd "/services/$service"
    if [ -f "/services/$service/setup.sh" ]; then
        /services/$service/setup.sh {team}
    fi
    docker compose up -d &
done

cat <<EOF | passwd
{password}
{password}
EOF

systemctl enable wg-quick@game
systemctl start wg-quick@game
"""


def gen_passwords(teams: int) -> None:
    for team in range(1, teams + 1):
        pw_file = Path(f"{DATA_DIR}/passwords/team{team}.txt")
        if not pw_file.exists():
            pw_file.write_text(secrets.token_hex(32))
        export_file = Path(f"{DATA_DIR}/export/portal/team{team}/password.txt")
        export_file.write_text(pw_file.read_text())


def gen_openvpn() -> None:
    pass
