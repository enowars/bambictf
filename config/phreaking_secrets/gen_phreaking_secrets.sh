#!/bin/sh
for i in $(seq 1 $1); do
    PHREAKING_SIM_KEY=$(openssl rand -hex 16)
    PHREAKING_GRPC_PASS=$(openssl rand -hex 16)
    echo "PHREAKING_SIM_KEY=$PHREAKING_SIM_KEY" > ./team$i.phreaking.secrets.txt
    echo "PHREAKING_GRPC_PASS=$PHREAKING_GRPC_PASS" >> ./team$i.phreaking.secrets.txt
done
