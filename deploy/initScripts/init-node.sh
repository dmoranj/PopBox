#!/bin/bash

apt-get update -y
apt-get dist-upgrade -y
apt-get install puppet -y

echo "@NODE_TAG-$(hostname)" > /etc/hostname
hostname $(cat /etc/hostname)

echo "@PM_IP puppet" >> /etc/hosts

cat << EOF >> /etc/puppet/puppet.conf

[agent]
splaylimit = 300
runinterval = 300
EOF

sed -i s/START=no/START=yes/g /etc/default/puppet
service puppet start

