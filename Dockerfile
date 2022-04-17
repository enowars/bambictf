FROM ubuntu:20.04

# Core deps
RUN apt-get update
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends tzdata
RUN apt-get install -y --no-install-recommends rsync git less tmux python3 curl wireguard python3-pip unzip file nano \
    software-properties-common gpg-agent # for ansible and packer install

# Ansible
RUN add-apt-repository --yes --update ppa:ansible/ansible && apt-get install -y ansible

# Terrorform
RUN ls -alh /usr/local/bin
RUN curl https://releases.hashicorp.com/terraform/1.0.11/terraform_1.0.11_linux_amd64.zip > terraform.zip && \
    unzip terraform.zip && \
    mv terraform /usr/local/bin/

# Packer
RUN curl -fsSL https://apt.releases.hashicorp.com/gpg | apt-key add - && \
    apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main" && \
    apt-get update && apt-get install packer

# openvpn
RUN apt-get install -y openvpn easy-rsa zip unzip
ENV PATH="/usr/share/easy-rsa:${PATH}"

# QOL
RUN echo "set -g mouse on" > /root/.tmux.conf

WORKDIR /bambictf

ENTRYPOINT tail -f /dev/null
