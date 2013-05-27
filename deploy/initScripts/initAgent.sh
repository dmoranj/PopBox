#!/bin/bash

apt-get update -y
apt-get dist-upgrade -y
apt-get install puppet -y

wget https://raw.github.com/dmoranj/PopBox/deployment/deploy/deployAgent.pp
puppet apply /deployAgent.pp

#chkconfig puppet on
#service puppet restart

echo "agent_$(hostname)" > /etc/hostname
