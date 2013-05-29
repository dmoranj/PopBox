#!/bin/bash

REDIS=$(cat /var/log/puppet/masterhttp.log |egrep .*PUT.*certificate_request.*redis.* |sed s/.*ip-// | grep -o "[0-9]*\-[0-9]*\-[0-9]*\-[0-9]*" | tr - .)

REDIS_OUT=""
for ip in $REDIS; do
  REDIS_OUT="$REDIS_OUT, {host: '$ip', port: 6379}"
done

REDIS_OUT=${REDIS_OUT:2}

sed -i "s/exports.redisServers = .*;/exports.redisServers = [$REDIS_OUT];/" /etc/puppet/modules/agentpopbox/files/baseConfig.js
sed -i "s/exports.tranRedisServer = .*;/exports.tranRedisServer = {host: '$REDIS_OUT[0]', port: 6379};/" /etc/puppet/modules/agentpopbox/files/baseConfig.js
