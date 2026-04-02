#!/bin/sh
#
# 
PASSWORD=$1

cd ~
curl -OL https://download.oracle.com/otn_software/apex/apex-latest.zip
unzip -q apex-latest.zip
mkdir oradata
mkdir ords_config
docker pull container-registry.oracle.com/database/free:latest
docker pull container-registry.oracle.com/database/ords:latest
echo "ORACLE_PWD=${PASSWORD}" > .env
docker compose up -d
