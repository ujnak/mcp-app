#!/bin/sh
#
# Configure the system to run nginx reverse proxy on Ubuntu 24.04.
#
# HISTORY
# 2026/03/02 ynakakos created.
#
set -e

# Update all installed packages to their latest versions.
#
sudo apt update -qq && sudo apt full-upgrade -y -qq && sudo apt autoremove -y -qq

# The universe repository is required solely to install nginx dynamic module libnginx-mod-http-headers-more-filter. 
# Specifically, it is only necessary when configuring a reverse proxy for MCP.
#
sudo apt install -y -qq software-properties-common
sudo add-apt-repository -y universe
sudo apt update -qq

# install packages to run nginx reverse proxy.
# 
sudo apt install -y -qq ufw vim \
    nginx certbot \
    libnginx-mod-http-headers-more-filter

# Stop and disable nginx
sudo systemctl stop nginx
sudo systemctl disable nginx

# Configure network filter.
#
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw --force enable
sudo ufw reload

# End of script.