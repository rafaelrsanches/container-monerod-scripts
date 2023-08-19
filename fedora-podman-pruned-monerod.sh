#!/bin/bash

## A script to run a pruned monero node with podman on Fedora, using SethForPrivacy docker image https://hub.docker.com/r/sethsimmons/simple-monerod ##

GREEN='\033[1;32m'
NC='\033[0m' # No Color

echo -e "${GREEN}Update your system, install ufw and curl${NC}"
sudo dnf update -y
sudo dnf install -y ufw curl

echo -e "${GREEN}Deny all non-explicitly allowed ports${NC}"
sudo ufw default deny incoming
sudo ufw default allow outgoing

echo -e "${GREEN}Allow SSH access${NC}"
sudo ufw allow ssh

echo -e "${GREEN}Allow monerod p2p port${NC}"
sudo ufw allow 18080/tcp

echo -e "${GREEN}Allow monerod restricted RPC port${NC}"
sudo ufw allow 18089/tcp

echo -e "${GREEN}Enable UFW${NC}"
sudo ufw enable

echo -e "${GREEN}Download container image and create a pruned monerod with Podman${NC}"
podman create --name=monerod --restart=always \
    -p 18080:18080 -p 18089:18089 \
    -v bitmonero:/home/monero \
    -l "io.containers.autoupdate=registry" \
    docker.io/sethsimmons/simple-monerod:latest \
    --rpc-restricted-bind-ip=0.0.0.0 \
    --rpc-restricted-bind-port=18089 \
    --no-igd --no-zmq --enable-dns-blocklist --prune-blockchain
    
echo -e "${GREEN}Create systemd service unit file at user level for monerod${NC}"
mkdir -p ~/.config/systemd/user/
podman generate systemd --new --name monerod > ~/.config/systemd/user/container-monerod.service

echo -e "${GREEN}Enable and start the monerod systemd service at user level${NC}"
systemctl --user enable ~/.config/systemd/user/container-monerod.service
systemctl --user start container-monerod.service

echo -e "${GREEN}Connect to your node using this address and port 127.0.0.1:18089${NC}"

## To watch the logs for monerod, simply run ##
journalctl --user-unit=container-monerod.service -f

## Connect to your node using this address and port ##
#127.0.0.1:18089

## To check the status of the monerod, simply run ##
#podman exec -it monerod monerod status

## To check for updates, simply run ##
#podman auto-update
