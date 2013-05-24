#!/bin/bash

. config.sh

# Log an error to the console
function error() {
  echo -e "\n\tError: $1\n";
}

# Show the script usage
function show_usage() {
  echo -e "Usage:"
  echo -e "\tdeploy.sh install [agents] [redisNodes] [branch]\n"
  echo -e "\tdeploy.sh help\n"
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
  	echo "Deploying branch $GIT_BRANCH in the minimal configuration"
	#ec2-run-instances $IMAGE -t $SIZE --region $REGION --key $KEYS -g $GROUP --user-data-file $INITFILE
  else
        echo "Deploying branch $GIT_BRANCH with $AGENT_NUMBER Agents connected to $REDIS_NUMBER Redis"
  fi
}

# Check the first command line argument to execute the corresponding action.
function dispatch_actions() {
  case "$1" in 
    install)
	echo "Deploying VMs"
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

