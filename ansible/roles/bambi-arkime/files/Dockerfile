FROM ubuntu:22.04
RUN apt-get update && apt-get install -y libwww-perl libjson-perl ethtool libyaml-dev liblua5.4-0 libmaxminddb0 libcurl4 libpcap0.8 libglib2.0-0 libnghttp2-14 libyara8 librdkafka1 curl

WORKDIR /BambiArkime
ADD https://github.com/arkime/arkime/releases/download/v5.0.0-rc1/arkime_5.0.0-rc1-1.ubuntu2204_amd64.deb .
RUN dpkg -i ./*.deb; apt-get install -fy

RUN touch /opt/arkime/etc/oui.txt
RUN touch /opt/arkime/etc/ipv4-address-space.csv

ENTRYPOINT /BambiArkime/docker-entrypoint.sh
