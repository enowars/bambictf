#!/bin/bash

GAME_NETWORK="10.0.0.0/16"
INTERNAL_NETWORK="192.168.0.0/20"
CHECKER_IP_PREFIX="192.168.1."
ROUTER_ADDRESS="192.168.0.2/20"
ENGINE_ADDRESS="192.168.1.0/32"
ROUTER_ENDPOINT=vpn.bambi.ovh:51821
ENGINE_ENDPOINT=engine-vpn.bambi.ovh:51821

if ! command -v wg; then
    echo "The command wg does not exist."
    exit 1;
fi

if [ "$#" -ne 1 ]; then
    echo "Please specify a number of checker configs. Usage: $0 <no of checkers>"
    exit 1;
fi

if ! [ "$1" -ge 1 ] || ! [ "$1" -le 240 ]; then
    echo "The number of checkers must be between 1 and 240."
    exit 1;
fi

router_privkey=$(wg genkey)
router_pubkey=$(echo "$router_privkey" | wg pubkey)

engine_privkey=$(wg genkey)
engine_pubkey=$(echo "$engine_privkey" | wg pubkey)

router_conf="$( cat <<-EOF
[Interface]
Address = $ROUTER_ADDRESS
PrivateKey = $router_privkey
ListenPort = 51821

[Peer]
PublicKey = $engine_pubkey
AllowedIPs = $ENGINE_ADDRESS
EOF
)"

engine_conf="$( cat <<-EOF
[Interface]
Address = $ENGINE_ADDRESS
PrivateKey = $engine_privkey
ListenPort = 51821

[Peer]
PublicKey = $router_pubkey
AllowedIPs = $GAME_NETWORK, $INTERNAL_NETWORK
Endpoint = $ROUTER_ENDPOINT
PersistentKeepalive = 15
EOF
)"

mkdir -p clients
for checker_id in $(seq 1 "$1"); do
    checker_ip="${CHECKER_IP_PREFIX}${checker_id}"
    echo $checker_ip
    privkey=$(wg genkey)
    echo $privkey
    pubkey=$(echo "$privkey" | wg pubkey)
    echo $pubkey
    echo $checker_id
    cat > "clients/checker${checker_id}.conf" <<EOF
[Interface]
Address = $checker_ip/32
PrivateKey = $privkey

[Peer]
PublicKey = $router_pubkey
AllowedIPs = $GAME_NETWORK, $INTERNAL_NETWORK
Endpoint = $ROUTER_ENDPOINT
PersistentKeepalive = 15

[Peer]
PublicKey = $engine_pubkey
AllowedIPs = $ENGINE_ADDRESS
Endpoint = $ENGINE_ENDPOINT
PersistentKeepalive = 15
EOF
    router_conf+=$(cat << EOF


[Peer]
PublicKey = $pubkey
AllowedIPs = ${checker_ip}/32
EOF
)

    engine_conf+=$(cat << EOF


[Peer]
PublicKey = $pubkey
AllowedIPs = ${checker_ip}/32
EOF
)
done

echo "$router_conf" > router.conf
echo "$engine_conf" > engine.conf
