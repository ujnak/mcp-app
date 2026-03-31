#!/bin/sh
#
# Configure the system to run nginx reverse proxy on Ubuntu 24.04.
#
# HISTORY
# 2026/03/31 ynakakos install OpenResty for reverse proxy.
# 2026/03/02 ynakakos created.
#

#
# Update all installed packages to their latest versions.
#
sudo apt update -qq && sudo apt full-upgrade -y -qq && sudo apt autoremove -y -qq

#
# The universe repository is required solely to install nginx dynamic module libnginx-mod-http-headers-more-filter. 
# Specifically, it is only necessary when configuring a reverse proxy for MCP.
#
sudo apt install -y -qq software-properties-common
sudo add-apt-repository -y universe
sudo apt update -qq

#
# install packages to run nginx reverse proxy.
# 
sudo apt install -y -qq ufw vim certbot


# Create user nginx and group nginx to run OpenRestry.
#
id nginx
if [ $? -ne 0 ]; then
    sudo groupadd --system --gid 101 nginx
    sudo useradd  --system --uid 101 --gid nginx --no-create-home --shell /sbin/nologin nginx
fi
sudo mkdir -p /var/log/nginx
sudo mkdir -p /etc/nginx/conf.d
sudo mkdir -p /etc/nginx/default.d
sudo mkdir -p /usr/share/nginx/html
sudo cp /usr/local/openresty/nginx/html/* /usr/share/nginx/html/

#
# Copy configuration files for OpenResty from GitHub
#
sudo curl -o /usr/local/openresty/nginx/conf/nginx.conf \
  https://raw.githubusercontent.com/ujnak/mcp-app/refs/heads/main/nginx/openresty-nginx.conf
sudo curl -o /etc/nginx/conf.d/01-server.conf \
 https://raw.githubusercontent.com/ujnak/mcp-app/refs/heads/main/nginx/01-server.conf
sudo curl -o /etc/nginx/default.d/10-root.conf \
 https://raw.githubusercontent.com/ujnak/mcp-app/refs/heads/main/nginx/10-root.conf
sudo curl -o /etc/nginx/default.d/50-ords.conf \
 https://raw.githubusercontent.com/ujnak/mcp-app/refs/heads/main/nginx/50-ords.conf
sudo curl -o /etc/nginx/default.d/60-apex-static-files.conf \
  https://raw.githubusercontent.com/ujnak/mcp-app/refs/heads/main/nginx/60-apex-static-files.conf
sudo curl -o /etc/nginx/default.d/90-error.conf \
  https://raw.githubusercontent.com/ujnak/mcp-app/refs/heads/main/nginx/90-error.conf

#
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

#
# Configure network filter.
#
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw --force enable
sudo ufw reload

#
# exit if no APEX is required.
#
#exit;

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
