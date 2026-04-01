#!/bin/sh
#
# Prepare Oracle Linux 10 to run Oracle Database Free and ORDS containers.
#
# HISTORY
# 2026/04/01 ynakakos Addition of a configuration option.
# 2026/03/31 ynakakos install OpenResty for reverse proxy.
# 2026/02/25 ynakakos rename the script to reflect its functionality.
# 2026/02/20 ynakakos created.
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
    INSTALL_APEX=false;
fi
# IS_ORACLE_LINUX: true if Oracle Linux.
IS_ORACLE_LINUX=${IS_ORACLE_LINUX:-true}
echo 'IS_ADB = ' ${IS_ADB}
echo 'INSTALL_APEX = ' ${INSTALL_APEX}
echo 'IS_ORACLE_LINUX = ' ${IS_ORACLE_LINUX}

#
# oci-growfs is available only in Oracle Linux images. 
# To align the size of the root filesystem with the boot volume,
# an expansion is required.
#
if [ -x /usr/libexec/oci-growfs ]; then 
    sudo /usr/libexec/oci-growfs -y
fi

#
# Update all installed packages to their latest versions.
#
sudo dnf -y -q update

#
# Enable the EPEL repository.
#
# for Oracle Linux 10 Update 1
sudo dnf config-manager --enable ol10_u1_developer_EPEL
# Other than Oracle Linux 10
#sudo dnf -y -q install epel-release

#
# Install certbot for TLS certificate issuance.
# After this script completes, run manually:
#   sudo systemctl stop openresty
#   sudo certbot --standalone -d your.domain.example.com
sudo dnf -y -q install certbot firewalld

#
# Create user nginx and group nginx to run OpenRestry.
#
id nginx > /dev/null 2>&1
if [ $? -ne 0 ]; then
    # Although this setup does not use the Alpine-based NGINX container, 
    # it aligns the UID and GID as closely as possible with those used by the container.
    sudo groupadd --system --gid 101 nginx
    sudo useradd  --system --uid 101 --gid nginx --no-create-home --shell /sbin/nologin nginx
fi
sudo mkdir -p /var/log/nginx
sudo mkdir -p /etc/nginx/conf.d
sudo mkdir -p /etc/nginx/default.d
sudo mkdir -p /usr/share/nginx/html

#
# Install OpenResty on Oracle Linux 10
# https://openresty.org/en/linux-packages.html#rhel
#
# RHEL 9 or later
curl -O https://openresty.org/package/rhel/openresty2.repo
# OpenResty does not provide the repositry for OL10 at this moment.
# use 9 instead.
sed -e 's/$releasever/9/' openresty2.repo > openresty.repo
rm -f openresty2.repo
# RHEL 8 or older
#curl -O https://openresty.org/package/rhel/openresty.repo
sudo mv openresty.repo /etc/yum.repos.d/openresty.repo
sudo dnf check-update
sudo dnf -y install openresty

# Setup document root.
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
# Update ACL for SELinux.
sudo restorecon -Rv /etc/nginx/

#
# Configure firewalld
#
# Not required on Oracle Linux, but safe to execute.
sudo systemctl enable firewalld
sudo systemctl start  firewalld
# ssh service allowed by default on OL10.
#sudo firewall-cmd --add-service=ssh
sudo firewall-cmd --add-service=http  # http on OpenResty
sudo firewall-cmd --add-service=https # https on OpenResty
if [ "${INSTALL_APEX}" = "true" ];then
    sudo firewall-cmd --add-port=8080/tcp   # http on ORDS
    sudo firewall-cmd --add-port=8443/tcp   # https on ORDS
    sudo firewall-cmd --add-port=27017/tcp  # MongoDB on ORDS
    sudo firewall-cmd --add-port=1521/tcp   # Oracle Net
    sudo firewall-cmd --add-port=1522/tcp   # Oracle Net (tcps)
fi
#　Use firewalld to perform port forwarding instead of nginx.
#sudo firewall-cmd --add-forward-port=port=80:proto=tcp:toport=8080
#sudo firewall-cmd --add-forward-port=port=443:proto=tcp:toport=8443
sudo firewall-cmd --runtime-to-permanent
sudo firewall-cmd --list-all

#
# Exit if APEX will not be installed on this host.
#
[ "$INSTALL_APEX" = "false" ] && exit 0

#
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

#
# Disable IPv6
#
sudo tee /etc/sysctl.d/60-disable-ipv6.conf > /dev/null <<EOF
net.ipv6.conf.all.disable_ipv6=1
net.ipv6.conf.default.disable_ipv6=1
EOF

#
# Align with the default configuration of Oracle Linux 
# for non-OL distribution, ex. Rocky Linux.
#
if [ "${IS_ORACLE_LINUX}" = "false" ]; then
    sudo tee /etc/sysctl.d/61-oracle.conf > /dev/null <<EOF
kernel.unknown_nmi_panic=1
kernel.io_uring_disabled=0
kernel.split_lock_mitigate=1
vm.hugetlb_optimize_vmemmap=1
EOF
fi
# Update system parameters.
sudo sysctl --system

#
# Install RPM packages required to run Oracle APEX and ORDS.
# container-tools: podman to run DB and ORDS containers.
# unzip: Used to extract apex-latest.zip.
# nginx, certbot, nginx-mod-headers-more: configure the reverse proxy.
# firewalld: port forwarding.
#
sudo dnf -y -q install container-tools unzip

# Allow nginx to connect to ORDS.
# 
sudo setsebool -P httpd_can_network_connect 1

# End of script.
