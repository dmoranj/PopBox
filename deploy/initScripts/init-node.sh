#!/bin/bash

apt-get update -y >> /var/log/syslog
apt-get dist-upgrade -y >> /var/log/syslog
apt-get install puppet -y >> /var/log/syslog

echo "@NODE_TAG-$(hostname)" > /etc/hostname
hostname $(cat /etc/hostname) >> /var/log/syslog

echo "@PM_IP puppet" >> /etc/hosts

cat << EOF >> /etc/puppet/puppet.conf

[agent]
splaylimit = 100
runinterval = 200
EOF

sed -i s/START=no/START=yes/g /etc/default/puppet >> /var/log/syslog
service puppet start >> /var/log/syslog

