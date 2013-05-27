#!/bin/bash

. config.sh

# Log an error to the console
function error() {
  echo -e "\n\t-> Error: $1\n";
}

# Log information to the console
function log() {
  echo -e "\t- $1";
}

# Log a task title to the console
function task() {
  echo -e "\n  *) $1";
}


# Show the script usage
function show_usage() {
  echo -e "Usage:"
  echo -e "\tdeploy.sh install [agents] [redisNodes] [branch]\n"
  echo -e "\tdeploy.sh help\n"
  exit 0
}

# Check if the EC2 environment is correctly set and working
function check_ec2_environment() {
  if [[ -z "$EC2_HOME" ]]; then
    error "Amazon installation base variable not defined";
    exit 1
  fi

  if [[ -z "$AWS_ACCESS_KEY" ]] || [[ -z "$AWS_SECRET_KEY" ]]; then
    error "Amazon EC2 Access Key or secret variables not defined";
    exit 1
  fi

  if [[ -z "$JAVA_HOME" ]]; then
    error "JAVA_HOME variable not defined";
    exit 1
  fi

  which ec2-describe-regions > /dev/null

  if [[ $? = 1 ]]; then
    error "EC2 Tools not installed or not found in path";
    exit 1
  fi
}

# Deploy a PopBox agent instance in EC2 that will be connected to an external redis.
function deploy_agent() {
  log "Deploying Popbox Agent number $1"
  INITFILE=./initScripts/initAgent.sh
  ec2-run-instances $IMAGE -t $SIZE --region $REGION --key $KEYS -g $GROUP --user-data-file $INITFILE
}

# Deploy a Redis instance in EC2
function deploy_redis() {
  log "Deploying Redis instance number $1"
  INITFILE=./initScripts/initRedis.sh
  ec2-run-instances $IMAGE -t $SIZE --region $REGION --key $KEYS -g $GROUP --user-data-file $INITFILE
}

# Deploy a minimal installation of PopBox composed of a single EC2 instance with 
# Redis and the PopBox agent
function deploy_minimal() {
  log "Deploying minimal instance"
  INITFILE=./initScripts/initMinimal.sh
  ec2-run-instances $IMAGE -t $SIZE --region $REGION --key $KEYS -g $GROUP --user-data-file $INITFILE
}

# Deploy the puppet master that will coordinate the configuration of the machines
function deploy_puppet_master() {
  log "Deploying puppet master"
  INITFILE=./initScripts/initPuppetMaster.sh
  ec2-run-instances $IMAGE -t $SIZE --region $REGION --key $KEYS -g $GROUP --user-data-file $INITFILE
}


# Deploy an instance of the full stack. The number of Popbox Agents and 
# Redis instances will be taken from the config files, unless overriden
# by the input parameters.
function deploy_vm () {
  if [[ -n "$1" ]]; then
    AGENT_NUMBER=$1
  fi;

  if [[ -n "$3" ]]; then
    GIT_BRANCH=$3
  fi;

  if [[ -n "$2" ]]; then
    REDIS_NUMBER=$2
  fi;

  if [[ $AGENT_NUMBER = 0 ]]; then
    task "Deploying branch $GIT_BRANCH in the minimal configuration"
    deploy_minimal
  else
    task "Deploying branch $GIT_BRANCH with $AGENT_NUMBER Agents connected to $REDIS_NUMBER Redis"

    deploy_puppet_master
    for i in `seq 1 $AGENT_NUMBER`;
    do
      deploy_agent $i
    done   
    for i in `seq 1 $REDIS_NUMBER`;
    do
      deploy_redis $i
    done 
  fi
}

# Check the first command line argument to execute the corresponding action.
function dispatch_actions() {
  case "$1" in 
    install)
	deploy_vm $2 $3 $4
    ;;
    help)
        show_usage
    ;;
    *)
	show_usage
    ;;
  esac
}

check_ec2_environment
dispatch_actions $1 $2 $3 $4

task "All actions finished\n"

