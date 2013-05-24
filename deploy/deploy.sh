#!/bin/bash

SIZE=t1.micro
REGION=eu-west-1
KEYS=dani-keys
GROUP=apigeetest
INITFILE=initSample.sh
IMAGE=ami-7e636a0a

ec2-run-instances $IMAGE -t $SIZE --region $REGION --key $KEYS -g $GROUP --user-data-file $INITFILE

