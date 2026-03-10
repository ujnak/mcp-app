#!/bin/sh
#
# Prepare Oracle Linux 10 to run Oracle Database Free and ORDS containers.
#
# HISTORY
# 2026/02/25 ynakakos rename the script to reflect its functionality.
# 2026/02/20 ynakakos created.
#

# oci-growfs is available only in Oracle Linux images. 
# To align the size of the root filesystem with the boot volume,
# an expansion is required.
#
if [ -x /usr/libexec/oci-growfs ]; then 
    sudo /usr/libexec/oci-growfs -y
fi

# Update all installed packages to their latest versions.
#
sudo dnf -y -q update

# Enable the EPEL repository.
#
# for Oracle Linux 10 Update 1
sudo dnf config-manager --enable ol10_u1_developer_EPEL
# Other than Oracle Linux 10
#sudo dnf -y -q install epel-release

# Install RPM packages required to run Oracle APEX and ORDS.
# container-tools: podman to run DB and ORDS containers.
# unzip: Used to extract apex-latest.zip.
# nginx, certbot, nginx-mod-headers-more: configure the reverse proxy.
# firewalld: port forwarding.
#
sudo dnf -y -q install container-tools unzip \
    nginx certbot nginx-mod-headers-more \
    firewalld

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

# Create the user and group to run Oracle Database and ORDS.
#
sudo groupadd -g 54321 oinstall
sudo useradd -u 54321 -g 54321 -m oracle
sudo loginctl enable-linger 54321

# Disable IPv6
#
cat <<EOF > 60-disable-ipv6.conf
net.ipv6.conf.all.disable_ipv6=1
net.ipv6.conf.default.disable_ipv6=1
EOF
sudo cp 60-disable-ipv6.conf /etc/sysctl.d/

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

# Allow nginx to connect to ORDS.
# 
sudo setsebool -P httpd_can_network_connect 1

# End of script.