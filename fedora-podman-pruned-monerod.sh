#!/bin/bash

## A script to run a pruned monero node with podman on Fedora, using sethforprivacy docker image https://hub.docker.com/r/sethsimmons/simple-monerod ##

## Update your system, install ufw and curl ##

echo "Update your system, install ufw and curl"
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
    -l "io.containers.autoupdate=registry" \
    docker.io/sethsimmons/simple-monerod:latest \
    --rpc-restricted-bind-ip=0.0.0.0 \
    --rpc-restricted-bind-port=18089 \
    --no-igd --no-zmq --enable-dns-blocklist --prune-blockchain
    
## Create systemd service unit file for monerod ##
podman generate systemd --new --name monerod | sudo tee /etc/systemd/system/container-monerod.service

# Enable and start the monerod systemd service at user level
systemctl --user enable /etc/systemd/system/container-monerod.service
systemctl --user start container-monerod.service


## If you want to run a public pruned node comment the 2 commands above, and uncomment the commands below ##
#podman create --name=monerod --restart=always \
#    -p 18080:18080 -p 18089:18089 \
#    -v bitmonero:/home/monero \
#    docker.io/sethsimmons/simple-monerod:latest \
#    --rpc-restricted-bind-ip=0.0.0.0 \
#    --rpc-restricted-bind-port=18089 \
#    --public-node --no-igd --no-zmq --enable-dns-blocklist --prune-blockchain

## To watch the logs for monerod, simply run ##
journalctl --user-unit=container-monerod.service -f

## To check the status of the monerod, simply run ##
#podman exec -it monerod monerod status

## To check for updates, simply run ##
#podman auto-update
