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

## Create a network to connect the containers to each other ##
echo -e "${GREEN}Create monerod-network on podman${NC}"
podman network create monerod-network

echo -e "${GREEN}Download container image and create a pruned monerod with Podman${NC}"
podman create --name=monerod --restart=always \
    --network monerod-network \
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

## Wait to monerod to start ##
sleep 60

echo -e "${GREEN}Connect to your node using this address and port 127.0.0.1:18089${NC}"

echo -e "${GREEN}Download container image and create the tor hidden service with Podman${NC}"
podman create --name=tor --restart=always \
    --network monerod-network \
    -v tor-keys:/var/lib/tor/hidden_service/ \
    -l "io.containers.autoupdate=registry" \
    -e TOR_EXTRA_OPTIONS="HiddenServiceDir /var/lib/tor/hidden_service/monerod
HiddenServiceVersion 3
HiddenServicePort 18080 monerod:18080
HiddenServicePort 18089 monerod:18089" \
    docker.io/goldy/tor-hidden-service

echo -e "${GREEN}Create systemd service unit file at user level for tor hidden service${NC}"
podman generate systemd --new --name tor > ~/.config/systemd/user/container-tor.service

echo -e "${GREEN}Enable and start the tor hidden service systemd service at user level${NC}"
systemctl --user enable ~/.config/systemd/user/container-tor.service
systemctl --user start container-tor.service

## Wait to tor hidden service to start ##
sleep 60

onion_address=$(podman exec -it tor cat /var/lib/tor/hidden_service/monerod/hostname | tr -d '\r')
full_onion_address="${onion_address}:18089"
echo "${full_onion_address}" > ~/Documents/OnionNodeAddress.txt
echo -e "${GREEN}${full_onion_address} is your node address on tor, and you can access it on ~/Documents/OnionNodeAddress.txt${NC}"

echo -e "${GREEN}Configuration completed, to watch the logs for monerod, simply run 'journalctl --user-unit=container-monerod.service -f' ${NC}"

echo -e "${GREEN}Download container image and create the i2pd service with Podman${NC}"
podman create --name=i2pd --restart=always \
    --network monerod-network \
    -v i2pd-keys:/home/i2pd/data/ \
    -l "io.containers.autoupdate=registry" \
    docker.io/purplei2p/i2pd


echo -e "${GREEN}Create systemd service unit file at user level for i2pd service${NC}"
podman generate systemd --new --name i2pd > ~/.config/systemd/user/container-i2pd.service

echo -e "${GREEN}Enable and start the i2pd service systemd service at user level${NC}"
systemctl --user enable ~/.config/systemd/user/container-i2pd.service
systemctl --user start container-i2pd.service
podman exec -it i2pd sh -c 'echo -e "[monerod-p2p]\ntype = http\nhost = monerod\nport = 18080\nkeys = monerod.dat\n\n[monerod-rpc]\ntype = http\nhost = monerod\nport = 18089\nkeys = monerod.dat" > /home/i2pd/data/tunnels.conf'
systemctl --user restart container-i2pd.service

## Wait to tor hidden service to start ##
sleep 60

i2pd_address=$(podman exec -it i2pd cat /home/i2pd/data/ | tr -d '\r')
full_i2pd_address="${i2pd_address}:18089"
echo "${full_i2pd_address}" > ~/Documents/I2PNodeAddress.txt
echo -e "${GREEN}${full_i2pd_address} is your node address on i2p, and you can access it on ~/Documents/I2PNodeAddress.txt${NC}"

echo -e "${GREEN}Configuration completed, to watch the logs for monerod, simply run 'journalctl --user-unit=container-monerod.service -f' ${NC}"
## journalctl --user-unit=container-monerod.service -f

## podman exec -it tor onions

## podman exec -it tor cat /var/lib/tor/hidden_service/monerod/hostname

## Connect to your node using this address and port ##
#127.0.0.1:18089

## To check the status of the monerod, simply run ##
#podman exec -it monerod monerod status

## To check for updates, simply run ##
#podman auto-update
