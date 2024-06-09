#!/bin/sh
set -e

PCAP_HEADER_SIZE=24
FILESIZE=$(stat -c%s "$1")

if [ "$FILESIZE" -gt "$PCAP_HEADER_SIZE" ]
then
    echo "moving $1 ($FILESIZE bytes)"
    mv $1 ../pcaps_arkime
    touch ../pcaps_arkime/$1
fi
