#!/bin/bash

apt-get update -y
apt-get dist-upgrade -y
apt-get install puppet -y

#chkconfig puppet on
#service puppet restart

echo "agent-$(hostname)" > /etc/hostname
hostname $(cat /etc/hostname)

