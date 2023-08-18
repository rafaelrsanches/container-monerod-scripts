#!/bin/bash

## A script to run a pruned monero node with podman on Fedora, using sethforprivacy docker image https://hub.docker.com/r/sethsimmons/simple-monerod ##

## Update your system and install curl ##

echo "Update your system and install curl"
sudo dnf update -y
sudo dnf install -y ufw curl

## Deny all non-explicitly allowed ports ##
sudo ufw default deny incoming
sudo ufw default allow outgoing

## Allow SSH access ##
sudo ufw allow ssh

## Allow monerod p2p port ##
sudo ufw allow 18080/tcp

## Allow monerod restricted RPC port ##
sudo ufw allow 18089/tcp

## Enable UFW ##
sudo ufw enable

## Download and create a pruned monerod via Podman ##
podman create --name=monerod --restart=always \
    -p 18080:18080 -p 18089:18089 \
    -v bitmonero:/home/monero \
    docker.io/sethsimmons/simple-monerod:latest \
    --rpc-restricted-bind-ip=0.0.0.0 \
    --rpc-restricted-bind-port=18089 \
    --no-igd --no-zmq --enable-dns-blocklist --prune-blockchain
    
## Create systemd service unit file for monerod ##
podman generate systemd --new --name monerod | sudo tee /etc/systemd/system/container-monerod.service

## Enable and start the monerod systemd service ##
sudo systemctl enable container-monerod.service
sudo systemctl start container-monerod.service

## ATÉ AQUI OK ##

    
## Start Podman Service: Enable and start the Podman service so that the Podman socket becomes available ##  
sudo systemctl enable --now podman
sudo systemctl start podman

## Running Watchtower for Automatic Container Updates ##
## Only works with sudo ##
sudo podman create --name=watchtower --restart=always \
    -v /var/run/podman/podman.sock:/var/run/podman/podman.sock \
    docker.io/containrrr/watchtower --cleanup \
    --monitor-only \
    --interval 300 \
    monerod tor
    
## Create systemd service unit file for Watchtower ##
## Only works with sudo ##
sudo podman generate systemd --new --name watchtower | sudo tee /etc/systemd/system/container-watchtower.service

## Enable and start the watchtower systemd service ##
sudo systemctl enable container-watchtower.service
sudo systemctl start container-watchtower.service
    
## If you want to run a public pruned node comment the 2 commands above, and uncomment the commands below ##
#podman run -d --name=monerod --restart=always \
#    -p 18080:18080 -p 18089:18089 \
#    -v bitmonero:/home/monero \
#    docker.io/sethsimmons/simple-monerod:latest \
#    --rpc-restricted-bind-ip=0.0.0.0 \
#    --rpc-restricted-bind-port=18089 \
#    --public-node --no-igd --no-zmq --enable-dns-blocklist --prune-blockchain
#
#podman run -d --name=watchtower --restart=always \
#    -v /var/run/podman/podman.sock:/var/run/podman/podman.sock \
#    docker.io/containrrr/watchtower --cleanup \
#    --monitor-only \
#    --interval 300 \
#    monerod tor


## To watch the logs for monerod, simply run ##
journalctl -u container-monerod.service -f

## To check the status of the monerod, simply run ##
#sudo podman exec -it monerod monerod status
