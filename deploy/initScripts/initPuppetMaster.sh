#!/bin/bash

apt-get update -y
apt-get dist-upgrade -y
apt-get install puppet puppetmaster unzip -y

cd /tmp
wget https://github.com/dmoranj/PopBox/archive/deployment.zip
unzip deployment.zip
cp -Rf PopBox-deployment/deploy/puppet /etc

echo "*" > /etc/puppet/autosign.conf

