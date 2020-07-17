#!/bin/bash

[ -f "/etc/openvpn/server/team.conf" ] && exit

rm -r /tmp/openvpn-ca
make-cadir /tmp/openvpn-ca
touch /tmp/openvpn-ca/vars
cd /tmp/openvpn-ca
chmod +x vars
./easyrsa init-pki
echo "CA" | ./easyrsa build-ca nopass
echo "server" | ./easyrsa gen-req server nopass
echo "yes" | ./easyrsa sign-req server server
echo "client" | ./easyrsa gen-req client nopass
echo "yes" | ./easyrsa sign-req client client
openssl dhparam -out /etc/openvpn/server/dh.pem 2048
openvpn --genkey --secret /etc/openvpn/server/ta.key
cp pki/ca.crt /etc/openvpn/server/
cp pki/issued/server.crt /etc/openvpn/server/
cp pki/private/server.key /etc/openvpn/server/
cat <<EOF > /etc/openvpn/server/team.conf
port 1194
proto udp
dev team
dev-type tun

ca /etc/openvpn/server/ca.crt
cert /etc/openvpn/server/server.crt
key /etc/openvpn/server/server.key

dh /etc/openvpn/server/dh.pem

mode server
tls-server
key-direction 0
tls-auth /etc/openvpn/server/ta.key
cipher AES-256-CBC
auth SHA256

topology subnet
ifconfig 10.0.240.1 255.255.255.0
push "topology subnet"
ifconfig-pool 10.0.240.2 10.0.240.254
route-gateway 10.0.240.1
push "route-gateway 10.0.240.1"
push "route 10.0.0.0 255.255.0.0"

keepalive 10 120
comp-lzo
persist-key
persist-tun
status /etc/openvpn/server/server.log
verb 3

duplicate-cn
EOF

cat <<EOF > /root/client.conf
proto udp
dev tun
remote $(ip a | grep eth0 | grep inet | awk '{ print $2 }' | cut -f1 -d'/') 1194
resolv-retry infinite
nobind

tls-client
remote-cert-tls server
key-direction 1
tls-auth /etc/openvpn/server/ta.key
cipher AES-256-CBC
auth SHA256

keepalive 10 120
comp-lzo
verb 3
pull

<ca>
$(cat /etc/openvpn/server/ca.crt)
</ca>
<tls-auth>
$(cat /etc/openvpn/server/ta.key)
</tls-auth>
<cert>
$(cat /tmp/openvpn-ca/pki/issued/client.crt)
</cert>
<key>
$(cat /tmp/openvpn-ca/pki/private/client.key)
</key>
EOF

/usr/bin/systemctl enable openvpn-server@team
/usr/bin/systemctl start openvpn-server@team
