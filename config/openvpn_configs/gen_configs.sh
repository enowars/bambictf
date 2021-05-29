#!/bin/bash

[ -f dh.pem ] || openssl dhparam -out dh.pem 2048
mkdir -p zips
rm zips/*.zip

for i in $(seq 1 $1); do
    gateway_id="$((($i - 1) % $2 + 1))"
    (
        rm -r /tmp/openvpn-ca
        mkdir /tmp/openvpn-ca
        touch /tmp/openvpn-ca/vars
        cd /tmp/openvpn-ca
        easyrsa init-pki
        cp /etc/easy-rsa/openssl-easyrsa.cnf /tmp/openvpn-ca/pki/
        cp -r /etc/easy-rsa/x509-types/ /tmp/openvpn-ca/
        echo "CA" | easyrsa build-ca nopass
        echo "server" | easyrsa gen-req server nopass
        echo "yes" | easyrsa sign-req server server
        echo "client" | easyrsa gen-req client nopass
        echo "yes" | easyrsa sign-req client client
    )
    (
        [ -d "team$i" ] && rm -r "team$i"
        mkdir "team$i" && cd "team$i"
        openvpn --genkey secret ta.key
        cp /tmp/openvpn-ca/pki/ca.crt .
        cp /tmp/openvpn-ca/pki/issued/server.crt .
        cp /tmp/openvpn-ca/pki/private/server.key .
        cp /tmp/openvpn-ca/pki/issued/client.crt .
        cp /tmp/openvpn-ca/pki/private/client.key .

        TEAM_SUBNET_PREFIX="10.$((($i - 1) / 250 + 1)).$((($i - 1) % 250 + 1))"
        REMOTE_ADDRESS="vpn${gateway_id}.bambi.ovh"
        SERVER_PORT="$(printf '3%04d' $i)"

        cat <<EOF > team${i}.conf
port ${SERVER_PORT}
local 0.0.0.0
proto udp
dev team${i}
dev-type tun

mode server
tls-server
key-direction 0
cipher AES-256-CBC
auth SHA256

topology subnet
ifconfig ${TEAM_SUBNET_PREFIX}.129 255.255.255.128
push "topology subnet"
ifconfig-pool ${TEAM_SUBNET_PREFIX}.130 ${TEAM_SUBNET_PREFIX}.254
route-gateway ${TEAM_SUBNET_PREFIX}.129
push "route-gateway ${TEAM_SUBNET_PREFIX}.129"
push "route 10.0.0.0 255.0.0.0"

keepalive 10 120
persist-key
persist-tun
status /etc/openvpn/server/server.log
verb 3

duplicate-cn

<ca>
$(cat ca.crt)
</ca>
<cert>
$(cat server.crt)
</cert>
<key>
$(cat server.key)
</key>
<tls-auth>
$(cat ta.key)
</tls-auth>
<dh>
$(cat ../dh.pem)
</dh>
EOF

        cat <<EOF > client.conf
proto udp
dev tun
remote ${REMOTE_ADDRESS} ${SERVER_PORT}
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
$(cat ca.crt)
</ca>
<tls-auth>
$(cat ta.key)
</tls-auth>
<cert>
$(cat client.crt)
</cert>
<key>
$(cat client.key)
</key>
EOF
        zip "../zips/gateway${gateway_id}.zip" "team${i}.conf"
    )
    rm -r /tmp/openvpn-ca
done