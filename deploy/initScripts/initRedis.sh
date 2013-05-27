#!/bin/bash

apt-get update -y
apt-get dist-upgrade -y
apt-get install puppet -y

echo "redis-$(hostname)" > /etc/hostname
hostname $(cat /etc/hostname)

echo "@PM_IP puppet" >> /etc/hosts


