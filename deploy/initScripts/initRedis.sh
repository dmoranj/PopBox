#!/bin/bash

apt-get update -y
apt-get dist-upgrade -y
apt-get install puppet -y

wget https://raw.github.com/dmoranj/PopBox/deployment/deploy/deployRedis.pp
puppet apply /deployRedis.pp

echo "redis_$(hostname)" > /etc/hostname

