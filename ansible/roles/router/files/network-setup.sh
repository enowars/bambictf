#!/bin/bash

print_usage() {
    echo    "Usage:"
    echo    "  $0 router  fd00:1337:0:<suffix>/<prefix length> <interface>"
    echo    "  $0 address fd00:1337:0:<suffix>"
    echo    "  $0 docker  fd00:1337:0:<suffix>/<prefix length> <docker-network-name>"
    echo    "  $0 stop"
    echo    "Configures this machine to connect to the internal network."
    echo    "    router:"
    echo    "      Act as a router for the specified subnet and provide"
    echo    "      DHCP & SLAAC address configuration for clients on that"
    echo    "      interface."
    echo    "    address:"
    echo    "      Assigns this machine a single address in the internal"
    echo    "      network."
    echo    "    docker:"
    echo    "      Create the docker network with the specified name and"
    echo    "      subnet and route it to the internal network."
    echo    "    stop:"
    echo    "      Do not route anything."
}

check_subnet() {
    IP=$(python3 -c \
"
from ipaddress import *
try:
    subnet=IPv6Network(\"$1\")
except AddressValueError as error:
    print (error)
    exit (1)
if subnet.prefixlen < 64:
    print (\"You can't specify a subnet that larger than a /64\")
    exit (1)
if subnet.supernet(subnet.prefixlen-48) != IPv6Network(\"fd00:1337::/48\"):
    print (\"Not a subnet of fd00:1337::/48\")
    exit (1)
print(str(subnet.hosts().__next__())+\"/\"+str(subnet.prefixlen))
")
    if [[ $? != 0 ]]; then
        echo "error with subnet: $IP" >&2
        exit 1
    fi
    echo $IP
}

get_last_ip() {
    IP=$(python3 -c \
"
from ipaddress import *
try:
    subnet=IPv6Network(\"$1\")
except AddressValueError as error:
    print (error)
    exit (1)
print(str(subnet[0xffff]))
")
    if [[ $? != 0 ]]; then
        echo "error with subnet: $IP" >&2
        exit 1
    fi
    echo $IP
}

check_address() {
    IP=$(python3 -c \
"
from ipaddress import *
try:
    address=IPv6Address(\"$1\")
except AddressValueError as error:
    print (error)
    exit (1)
if address not in IPv6Network(\"fd00:1337::/48\"):
    print(\"The address is not in the fd00:1337::/48 network!\")
    exit(1)
print(address)
")
    if [[ $? != 0 ]]; then
        echo "error with address: $IP" >&2
        exit 1
    fi
    echo $IP
}

check_iface() {
    IFACES=$(/sbin/ip a \
        | grep -E "^[0-9]+:" \
        | grep -oE "^[0-9]+: [0-9a-z]+:" \
        | grep -oE "[0-9a-z]+:$" \
        | grep -oE "^[0-9a-z]+")
    echo "$IFACES" | grep -o "$1"
    if [[ $? != 0 ]]; then
        echo -e "error with interface: couldn't find interface! must be one of:\n$IFACES" >&2
        exit 1
    fi
}

configure_router() {

    systemctl stop radvd
    systemctl stop isc-dhcp-server

    SUBNET=$1
    IP=$(check_subnet $SUBNET)
    if [[ $? != 0 ]]; then exit 1; fi
    IFACE=$(check_iface $2)
    if [[ $? != 0 ]]; then exit 1; fi

    echo "Routing $SUBNET with address $IP on interface $IFACE"

    /sbin/ip link set "$IFACE" down
    /sbin/ip -6 address flush dev "$IFACE"
    /sbin/ip -6 address add "$IP" dev "$IFACE"
    /sbin/ip link set "$IFACE" up

    rm -f /etc/openvpn/static_address

    cp /etc/radvd.conf.subnet /etc/radvd.conf
    sed -i -e "s/SUBNET/${SUBNET/\//\\\/}/g" /etc/radvd.conf
    sed -i -e "s/IFACE/$IFACE/g" /etc/radvd.conf

    cp /etc/dhcp/dhcpd6.conf.orig /etc/dhcp/dhcpd6.conf
    sed -i -e "s/SUBNET/${SUBNET/\//\\\/}/g" /etc/dhcp/dhcpd6.conf
    sed -i -e "s/ADDRESS/${IP/\/[0-9]*/}/g" /etc/dhcp/dhcpd6.conf
    sed -i -e "s/^INTERFACESv6=\".*$/INTERFACESv6=\"$IFACE\"/g" /etc/default/isc-dhcp-server

    systemctl start radvd
    systemctl start isc-dhcp-server
}

configure_address() {

    systemctl stop radvd
    systemctl stop isc-dhcp-server

    IP=$(check_address $1)
    if [[ $? != 0 ]]; then exit 1; fi

    echo "Configuring $IP on the internal network"

    echo "$IP">/etc/openvpn/static_address
    /sbin/ip -6 address add "$IP/128" dev game_internal

    cp /etc/radvd.conf.address /etc/radvd.conf
    sed -i -e "s/ADDRESS/$IP/g" /etc/radvd.conf

    systemctl start radvd
}

configure_docker() {

    systemctl stop radvd
    systemctl stop isc-dhcp-server

    SUBNET=$1
    D_NET=$2
    IP=$(check_subnet $SUBNET)
    if [[ $? != 0 ]]; then exit 1; fi
    GW=$(get_last_ip $SUBNET)
    if [[ $? != 0 ]]; then exit 1; fi

    echo "Routing $SUBNET with address $IP to docker network $2"

    rm -f /etc/openvpn/static_address

    cp /etc/radvd.conf.docker /etc/radvd.conf
    sed -i -e "s/SUBNET/${SUBNET/\//\\\/}/g" /etc/radvd.conf

    docker network inspect "$2" >/dev/null 2>/dev/null
    if [[ $? != 0 ]]; then
        docker network create "$2" --ipv6 --subnet "$SUBNET" --gateway "$GW"
    fi

    systemctl start radvd
}

case $1 in
    router)
        shift 1
        configure_router $@
    ;;
    address)
        shift 1
        configure_address $@
    ;;
    docker)
        shift 1
        configure_docker $@
    ;;
    stop)
        systemctl stop radvd
        systemctl stop dhcpd
    ;;
    *)
        print_usage
    ;;
esac

