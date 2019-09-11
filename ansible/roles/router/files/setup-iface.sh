#!/bin/bash
/sbin/sysctl -w "net.ipv6.conf.$1.accept_ra=2" \
    "net.ipv6.conf.$1.accept_ra_rt_info_max_plen=128" \
    "net.ipv6.conf.$1.accept_ra_defrtr=0"
if [[ -f /etc/openvpn/static_address ]]; then
    /sbin/ip -6 address add "$(cat /etc/openvpn/static_address)" dev "$1"
fi
