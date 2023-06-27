#!/bin/bash

TEAM_COUNT=$(if [ -z "$TEAM_COUNT" ]; then echo 255; else echo "$TEAM_COUNT"; fi)
GATEWAY_COUNT=$(if [ -z "$GATEWAY_COUNT" ]; then echo 2; else echo "$GATEWAY_COUNT"; fi)
CHECKER_COUNT=$(if [ -z "$CHECKER_COUNT" ]; then echo 4; else echo "$CHECKER_COUNT"; fi)

mkdir -p "export"
mkdir -p "internal_router"
mkdir -p "wireguard_router"
mkdir -p "openvpn_configs"
mkdir -p "passwords"

(
    cd "internal_router"
    ./gen_keys.py $TEAM_COUNT $GATEWAY_COUNT $CHECKER_COUNT
)
(
    cd "wireguard_router"
    ./gen_keys.py $TEAM_COUNT $GATEWAY_COUNT
)
(
    cd "openvpn_configs"
    ./gen_configs.sh $TEAM_COUNT $GATEWAY_COUNT
)
(
    cd "passwords"
    ./gen_passwords.sh $TEAM_COUNT
)
(
    cd "phreaking_secrets"
    ./gen_phreaking_secrets.sh $TEAM_COUNT
)

for i in $(seq 1 ${TEAM_COUNT}); do
    mkdir -p "export/team$i"
    cat <<OUTEREOF > "export/team$i/user_data.sh"
#!/bin/sh
cat <<EOF >> /etc/wireguard/game.conf
$(cat "wireguard_router/team_configs/team${i}.conf" )
EOF
systemctl enable wg-quick@game
systemctl start wg-quick@game

cat <<EOF > /services/phreaking/.env
COMPOSE_PROJECT_NAME=phreaking_service
$(cat "phreaking_secrets/team$i.phreaking.secrets.txt")
EOF

for service in \$(ls /services/); do
    cd "/services/\$service"
    if [ -f "/services/\$service/setup.sh" ]; then
        /services/\$service/setup.sh
    fi
    docker-compose up -d &
done

cat <<EOF | passwd
$(cat passwords/team${i}.txt | tr -d '\n')
$(cat passwords/team${i}.txt | tr -d '\n')
EOF
OUTEREOF

    cp "passwords/team${i}.txt" "export/team${i}/root.pw"
    cp "openvpn_configs/team${i}/client.conf" "export/team${i}/client.conf"
    cp "wireguard_router/team_configs/team${i}.conf" "export/team${i}/wireguard.conf"
done
