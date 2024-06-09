FROM ubuntu:23.10

# Core deps
RUN apt-get update
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends tzdata
RUN apt-get install -y --no-install-recommends openssh-client rsync git less tmux python3 curl wireguard unzip file nano dnsutils jq \
    software-properties-common gpg-agent pipx # for ansible and packer install

# Poetry and Ansible
RUN pipx install poetry && pipx install --include-deps ansible && pipx inject ansible ansible-lint --include-apps --include-deps
ENV PATH="/root/.local/bin:${PATH}"

# Packer and Terraform
RUN curl -fsSL https://apt.releases.hashicorp.com/gpg | apt-key add - && \
    apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main" && \
    apt-get update && apt-get install packer terraform && \
    packer plugins install github.com/hashicorp/hcloud && \
    packer plugins install github.com/hashicorp/ansible

# OpenVPN
RUN apt-get install -y openvpn easy-rsa zip unzip
ENV PATH="/usr/share/easy-rsa:${PATH}"

# QOL
RUN echo "set -g mouse on" > /root/.tmux.conf

# fix SSH host key checking
# RUN mkdir /root/.ssh && echo "Host 127.0.0.1\n  HostKeyAlgorithms=+ssh-rsa\n  PubkeyAcceptedKeyTypes=+ssh-rsa" > /root/.ssh/config

WORKDIR /bambictf

ENTRYPOINT tail -f /dev/null
