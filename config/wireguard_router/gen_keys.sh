#!/bin/bash

GAME_NETWORK="10.0.0.0/16"
TEAM_IP_PREFIX="10.0.0."
ROUTER_ADDRESS="10.0.1.1/16"
ROUTER_ENDPOINT=vpn.bambi.ovh:51820

if ! command -v wg; then
    echo "The command wg does not exist."
    exit 1;
fi

if [ "$#" -ne 1 ]; then
    echo "Please specify a number of teams. Usage: $0 <no of teams>"
    exit 1;
fi

if ! [ "$1" -ge 1 ] || ! [ "$1" -le 240 ]; then
    echo "The number of teams must be between 1 and 240."
    exit 1;
fi

router_privkey=$(wg genkey)
router_pubkey=$(echo "$router_privkey" | wg pubkey)

router_conf="$( cat <<-EOF
[Interface]
Address = $ROUTER_ADDRESS
PrivateKey = $router_privkey
ListenPort = 51820
EOF
)"

mkdir -p clients
for team_id in $(seq 1 "$1"); do
    team_ip="${TEAM_IP_PREFIX}${team_id}"
    echo $team_ip
    privkey=$(wg genkey)
    echo $privkey
    pubkey=$(echo "$privkey" | wg pubkey)
    echo $pubkey
    echo $team_id
    cat > "clients/team${team_id}.conf" <<EOF
[Interface]
Address = $team_ip/32
PrivateKey = $privkey

[Peer]
PublicKey = $router_pubkey
AllowedIPs = $GAME_NETWORK
Endpoint = $ROUTER_ENDPOINT
PersistentKeepalive = 15
EOF
    router_conf+=$(cat << EOF


[Peer]
PublicKey = $pubkey
AllowedIPs = ${team_ip}/32
EOF
)
done

echo "$router_conf" > router.conf