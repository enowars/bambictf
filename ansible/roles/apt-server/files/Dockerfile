FROM phusion/baseimage:0.11

# Use baseimage-docker's init system.
CMD ["/sbin/my_init"]
# Set up aptly
RUN echo "deb http://repo.aptly.info/ squeeze main" > /etc/apt/sources.list.d/aptly.list
COPY ED75B5A4483DA07C.pub /tmp/ED75B5A4483DA07C.pub
RUN apt-key add /tmp/ED75B5A4483DA07C.pub
RUN apt-get update
RUN apt-get install -y aptly gnupg1 ca-certificates
# Clean up 
COPY aptly.conf /root/.aptly.conf
COPY enowars.pub.gpg /root/.aptly/public/pub.gpg
COPY enowars.priv.gpg /root/priv.gpg
RUN gpg1 --import /root/.aptly/public/pub.gpg
RUN gpg1 --allow-secret-key-import --import /root/priv.gpg
RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
EXPOSE 8080