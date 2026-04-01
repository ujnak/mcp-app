#!/bin/sh
#
# Configure the system to run nginx reverse proxy on Ubuntu 24.04.
#
# HISTORY
# 2026/04/01 ynakakos Addition of a configuration option.
# 2026/03/31 ynakakos install OpenResty for reverse proxy.
# 2026/03/02 ynakakos created.
#

#
# Configuration Options:
#
# IS_ADB: true if backend is Autonomous AI Database, default false.
IS_ADB=${IS_ADB:-false}
if [ "${IS_ADB}" = "false" ]; then
    # INSTALL_APEX: Install Container environment to install APEX.
    INSTALL_APEX=${INSTALL_APEX:-true}
else
    # Container is not required when backend is ADB.
    INSTALL_APEX=false
fi
echo 'IS_ADB = ' ${IS_ADB}
echo 'INSTALL_APEX = ' ${INSTALL_APEX}

#
# Update all installed packages to their latest versions.
#
# Do full-upgrade to ensure installed packages as minimal.
sudo apt update -qq && sudo apt full-upgrade -y -qq && sudo apt autoremove -y -qq

#
# Install certbot for TLS certificate issuance.
# After this script completes, run manually:
#   sudo systemctl stop openresty
#   sudo certbot --standalone -d your.domain.example.com
sudo apt install -y -qq ufw vim certbot

#
# Create user nginx and group nginx to run OpenRestry.
#
id nginx > /dev/null 2>&1
if [ $? -ne 0 ]; then
    # Although this setup does not use the Alpine-based NGINX container,
    # it aligns the UID and GID as closely as possible with those used by the container.
    grep -q '^nginx:' /etc/group || sudo groupadd --system --gid 101 nginx
    sudo useradd  --system --uid 101 --gid nginx --no-create-home --shell /sbin/nologin nginx
fi
sudo mkdir -p /var/log/nginx
sudo mkdir -p /etc/nginx/conf.d
sudo mkdir -p /etc/nginx/default.d
sudo mkdir -p /usr/share/nginx/html

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

# setup document root.
sudo cp /usr/local/openresty/nginx/html/* /usr/share/nginx/html/

#
# Copy configuration files for OpenResty from GitHub
#
sudo curl --fail -o /usr/local/openresty/nginx/conf/nginx.conf \
  https://raw.githubusercontent.com/ujnak/mcp-app/refs/heads/main/nginx/openresty-nginx.conf
sudo curl --fail -o /etc/nginx/conf.d/01-server.conf \
 https://raw.githubusercontent.com/ujnak/mcp-app/refs/heads/main/nginx/01-server.conf
sudo curl --fail -o /etc/nginx/default.d/10-root.conf \
 https://raw.githubusercontent.com/ujnak/mcp-app/refs/heads/main/nginx/10-root.conf
sudo curl --fail -o /etc/nginx/default.d/90-error.conf \
  https://raw.githubusercontent.com/ujnak/mcp-app/refs/heads/main/nginx/90-error.conf
# MCP
if [ "${IS_ADB}" = "false" ]; then
  sudo curl --fail -o /etc/nginx/default.d/30-mcp.conf \
    https://raw.githubusercontent.com/ujnak/mcp-app/refs/heads/main/nginx/30-mcp.conf
else
  sudo curl --fail -o /etc/nginx/default.d/30-mcp-adb.conf \
    https://raw.githubusercontent.com/ujnak/mcp-app/refs/heads/main/nginx/30-mcp-adb.conf
fi
sudo curl --fail -o /etc/nginx/default.d/40-www-auth.conf \
  https://raw.githubusercontent.com/ujnak/mcp-app/refs/heads/main/nginx/40-www-auth.conf
# APEX (Do not use with Autonomous Database)
if [ "${IS_ADB}" = "false" ]; then
    sudo curl --fail -o /etc/nginx/default.d/50-ords.conf \
      https://raw.githubusercontent.com/ujnak/mcp-app/refs/heads/main/nginx/50-ords.conf
    sudo curl --fail -o /etc/nginx/default.d/60-apex-static-files.conf \
      https://raw.githubusercontent.com/ujnak/mcp-app/refs/heads/main/nginx/60-apex-static-files.conf
fi

#
# Configure network filter.
#
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp  # http on OpenResty
sudo ufw allow 443/tcp # https on OpenResty
if [ "${INSTALL_APEX}" = "true" ];then
    sudo ufw allow 8080/tcp  # http on ORDS
    sudo ufw allow 8443/tcp  # https on ORDS
    sudo ufw allow 27017/tcp # MongoDB on ORDS
    sudo ufw allow 1521/tcp  # Oracle Net
    sudo ufw allow 1522/tcp  # Oracle Net (tcps)
fi
sudo ufw --force enable
sudo ufw reload

#
# exit if no APEX is required.
# default: true
[ "$INSTALL_APEX" = "false" ] && exit 0

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
id oracle > /dev/null 2>&1
if [ $? -ne 0 ]; then
    # UID of oracle user in the Oracle container is 54321,
    # and GID of oinstall group is 54321.
    grep -q '^oinstall:' /etc/group || sudo groupadd -g 54321 oinstall
    sudo useradd -u 54321 -g 54321 -m oracle
fi
sudo loginctl enable-linger 54321
sudo usermod -aG docker oracle

# End of script.
