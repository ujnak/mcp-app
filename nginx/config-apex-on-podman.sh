#!/bin/sh

PASSWORD=$1

cd ~
curl -OL https://download.oracle.com/otn_software/apex/apex-latest.zip
unzip -q apex-latest.zip
mkdir oradata
mkdir ords_config
podman pull container-registry.oracle.com/database/free:latest
podman pull container-registry.oracle.com/database/ords:latest
curl -O https://raw.githubusercontent.com/ujnak/mcp-app/refs/heads/main/nginx/apex.yml
sed -i "s|\$ORASYSPWD|${PASSWORD}|g" apex.yml
podman play kube apex.yml
