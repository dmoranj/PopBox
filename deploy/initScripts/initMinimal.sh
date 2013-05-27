#!/bin/bash

apt-get update -y
apt-get dist-upgrade -y
apt-get install puppet -y

wget https://raw.github.com/dmoranj/PopBox/deployment/deploy/deploy.pp
puppet apply /deploy.pp