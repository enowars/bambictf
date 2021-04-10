#!/bin/bash

mkdir "export"

(
    cd "internal_router"
    ./gen_keys.sh 20   
)
(
    cd "wireguard_router"
    ./gen_keys.sh "$1"
)
(
    cd "openvpn_configs"
    ./gen_configs.sh "$1"
)
(
    cd "passwords"
    ./gen_passwords.sh "$1"
)

for i in $(seq 1 $1); do
    mkdir "export/team$i"
    cat <<OUTEREOF > "export/team$i/user_data.sh"
#!/bin/sh
cat <<EOF >> /etc/wireguard/game.conf
$(cat "wireguard_router/clients/team${i}.conf" )
EOF
systemctl enable wg-quick@game
systemctl start wg-quick@game

# provision OpenVPN server for team access
cat <<EOF >> /etc/openvpn/server/team.conf
$(cat "openvpn_configs/team${i}/team.conf")
EOF

systemctl enable openvpn-server@team
systemctl start openvpn-server@team

for service in \$(ls /services/); do
cd "/services/\$service" && docker-compose up -d &
done

cat <<EOF | passwd
$(cat passwords/team${i}.txt | tr -d '\n')
$(cat passwords/team${i}.txt | tr -d '\n')
EOF
OUTEREOF

    cp "passwords/team${i}.txt" "export/team${i}/root.pw"
    cp "openvpn_configs/team${i}/client.conf" "export/team${i}/client.conf"
done