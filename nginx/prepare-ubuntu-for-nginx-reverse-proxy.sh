#!/bin/sh
#
# Configure the system to run nginx reverse proxy on Ubuntu 24.04.
#
# HISTORY
# 2026/03/31 ynakakos install OpenResty for reverse proxy.
# 2026/03/02 ynakakos created.
#
#set -e

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
sudo apt install -y -qq ufw vim unzip \
    certbot \
    nginx libnginx-mod-http-headers-more-filter

# Stop and disable nginx
sudo systemctl stop nginx
sudo systemctl disable nginx

# Install OpenResty on Ubuntu 24.04
# https://openresty.org/en/linux-packages.html#ubuntu
# Ubuntu 22 or later
sudo apt-get -y install --no-install-recommends wget gnupg ca-certificates lsb-release
wget -O - https://openresty.org/package/pubkey.gpg | sudo gpg --dearmor --yes -o /usr/share/keyrings/openresty.gpg
# x86_64 or amd64
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/openresty.gpg] http://openresty.org/package/ubuntu $(lsb_release -sc) main" | sudo tee /etc/apt/sources.list.d/openresty.list > /dev/null
# arm64 or aarch64
#echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/openresty.gpg] http://openresty.org/package/arm64/ubuntu $(lsb_release -sc) main" | sudo tee /etc/apt/sources.list.d/openresty.list > /dev/null
#
sudo apt-get update
sudo apt-get -y install openresty
# sudo apt-get -y install --no-install-recommends openresty
# create openresty.service
cat <<EOF > openresty.service
[Unit]
Description=The OpenResty Application Platform
After=syslog.target network-online.target remote-fs.target nss-lookup.target
Wants=network-online.target

[Service]
Type=forking
PIDFile=/run/openresty.pid
ExecStartPre=/usr/local/openresty/nginx/sbin/nginx -t -c /etc/nginx/openresty-nginx.conf
ExecStart=/usr/local/openresty/nginx/sbin/nginx -c /etc/nginx/openresty-nginx.conf
ExecStartPost=/bin/sleep 1
ExecReload=/bin/kill -s HUP \$MAINPID
ExecStop=/bin/kill -s QUIT \$MAINPID
RuntimeDirectory=openresty
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF
# Install OpenResty service.
sudo mv openresty.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl status openresty

# Configure network filter.
#
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw --force enable
sudo ufw reload

#########################################################################
# remove if APEX will not be installed.
# 
# Install Docker
#
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Create the user and group to run Oracle Database and ORDS.
#
sudo groupadd -g 54321 oinstall
sudo useradd -u 54321 -g 54321 -m oracle
sudo loginctl enable-linger 54321
sudo usermod -aG docker oracle

# End of script.
