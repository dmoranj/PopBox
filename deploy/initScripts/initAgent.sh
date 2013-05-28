#!/bin/bash

apt-get update -y
apt-get dist-upgrade -y
apt-get install puppet -y

echo "agent-$(hostname)" > /etc/hostname
hostname $(cat /etc/hostname)

echo "@PM_IP puppet" >> /etc/hosts

sed -i s/START=no/START=yes/g /etc/default/puppet
service puppet start

