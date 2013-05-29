#!/bin/bash

apt-get update -y
apt-get dist-upgrade -y
apt-get install puppet puppetmaster unzip -y

cd /root
wget https://github.com/dmoranj/PopBox/archive/deployment.zip
unzip deployment.zip
cp -Rf PopBox-deployment/deploy/puppet /etc

chmod +x PopBox-deployment/deploy/initScripts/detectRedis.sh

echo "*" > /etc/puppet/autosign.conf
echo -e "* * * * * root /root/PopBox-deployment/deploy/initScripts/detectRedis.sh  > /root/redisUp.log\n" >> /etc/crontab
service cron restart

