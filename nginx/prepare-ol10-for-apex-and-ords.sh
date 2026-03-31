#!/bin/sh
#
# Prepare Oracle Linux 10 to run Oracle Database Free and ORDS containers.
#
# HISTORY
# 2026/03/31 ynakakos install OpenResty for reverse proxy.
# 2026/02/25 ynakakos rename the script to reflect its functionality.
# 2026/02/20 ynakakos created.
#

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
# Install RPM packages required to run the reverse proxy.
#
sudo dnf -y -q install certbot firewalld

#
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
# Update ACL for SELinux.
sudo restorecon -Rv /etc/nginx/

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

#
# Configure firewalld
#
# Not required on Oracle Linux, but safe to execute.
sudo systemctl enable firewalld
sudo systemctl start  firewalld
# ssh service allowed by default on OL10.
#sudo firewall-cmd --add-service=ssh
sudo firewall-cmd --add-service=http
sudo firewall-cmd --add-service=https
sudo firewall-cmd --add-port=8080/tcp
sudo firewall-cmd --add-port=8443/tcp
sudo firewall-cmd --add-port=27017/tcp
sudo firewall-cmd --add-port=1521/tcp
#　Use firewalld to perform port forwarding instead of nginx.
#sudo firewall-cmd --add-forward-port=port=80:proto=tcp:toport=8080
#sudo firewall-cmd --add-forward-port=port=443:proto=tcp:toport=8443
sudo firewall-cmd --runtime-to-permanent
sudo firewall-cmd --list-all

#
# exit if no APEX is required.
#
#exit;

#
# Create the user and group to run Oracle Database and ORDS.
#
sudo groupadd -g 54321 oinstall
sudo useradd -u 54321 -g 54321 -m oracle
sudo loginctl enable-linger 54321

#
# Disable IPv6
#
cat <<EOF > 60-disable-ipv6.conf
net.ipv6.conf.all.disable_ipv6=1
net.ipv6.conf.default.disable_ipv6=1
EOF
sudo cp 60-disable-ipv6.conf /etc/sysctl.d/

#
# Align with the default configuration of Oracle Linux 
# for non-OL distribution, ex. Rocky Linux.
#
cat <<EOF > 61-oracle.conf
kernel.unknown_nmi_panic=1
kernel.io_uring_disabled=0
kernel.split_lock_mitigate=1
vm.hugetlb_optimize_vmemmap=1
EOF
# Do not apply this on Oracle Linux.
#sudo cp 61-oracle.conf /etc/sysctl.d/
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
