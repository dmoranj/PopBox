#!/bin/bash

. config.sh

# DEFINITIONS
####################################################################
TMP_FOLDER=/tmp
declare -A LAYER_IDS
declare -A LAYER_OUT_IPS
declare -A LAYER_IN_IPS

# FUNCTIONS
####################################################################

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
  echo -e "\n  *) $1\n";
}


# Show the script usage
function show_usage() {
  echo -e "Usage:"
  echo -e "\tdeploy.sh install [agents] [redisNodes] [branch]\n"
  echo -e "\tdeploy.sh remove <summary_file>\n"
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

# Wait for a EC2 instance to be deployed
function wait_for() {
  IID=$1
  log "Waiting for instance $IID" 

  TIMES=0
  while [ 10 -gt $TIMES ] && ! ec2-describe-instances --region $REGION $IID | grep -q "running"
  do
    TIMES=$(( $TIMES + 1 ))
    log "Verifying state of instance $IID"
    sleep 25
  done 

  STATUS=$(ec2-describe-instance-status --region $REGION $IID | awk '/^INSTANCE/ {print $4}' | head -n 1)

  if [ "$STATUS" = "running" ]; then 
    log "Instance successfully installed"
  else
    error "Instance ended in an unexpected state: $STATUS" 
  fi  
}

# Extract the IPs of the redis using its instance ID and add it to the global array
function extract_node_data() {
  INSTANCE_ID=$1
  OUTPUT=$(ec2-describe-instances --region $REGION $INSTANCE_ID)
  NODE_IN_IP=$(echo $OUTPUT | awk '{print $19}')
  NODE_OUT_IP=$(echo $OUTPUT | awk '{print $18}')
  LAYER_IN_IPS[$2]+=" $NODE_IN_IP"
  LAYER_OUT_IPS[$2]+=" $NODE_OUT_IP"
  log "$2: InternalIP($NODE_IN_IP), ExternalIP($NODE_OUT_IP)"
}

# Deploy a Redis instance in EC2
function deploy_node() {
  task "Deploying <<$2>> instance number $1"
  INITFILE=$TMP_FOLDER/init-$2.sh
  OUTPUT=$(ec2-run-instances $IMAGE -t $SIZE_REDIS --region $REGION --key $KEYS -g $GROUP --user-data-file $INITFILE)
  INSTANCE_ID=$(echo $OUTPUT|awk '{print $6}')
  LAYER_IDS[$2]+=" $INSTANCE_ID"

  wait_for $INSTANCE_ID
  extract_node_data $INSTANCE_ID $2
}

# Deploy a minimal installation of PopBox composed of a single EC2 instance with 
# Redis and the PopBox agent
function deploy_minimal() {
  task "Deploying minimal instance"
  INITFILE=./initScripts/initMinimal.sh
  OUTPUT=$(ec2-run-instances $IMAGE -t $SIZE_AGENT --region $REGION --key $KEYS -g $GROUP --user-data-file $INITFILE)
  INSTANCE_ID=$(echo $OUTPUT|awk '{print $6}')

  wait_for $INSTANCE_ID
}

# Extract the Puppet Master data from its instance ID in EC2
function extract_puppet_master_data() {
  INSTANCE_ID=$1
  OUTPUT=$(ec2-describe-instances --region $REGION $INSTANCE_ID)
  PM_OUT_IP=$(echo $OUTPUT | awk '{print $18}')
  PM_IN_IP=$(echo $OUTPUT | awk '{print $19}')
  log "Puppet Master: InternalIP($PM_IN_IP), ExternalIP($PM_OUT_IP)"
}

function create_init_scripts() {
  cat initScripts/init-agent.sh | sed s/@PM_IP/$PM_IN_IP/g > $TMP_FOLDER/init-agent.sh
  cat initScripts/init-redis.sh | sed s/@PM_IP/$PM_IN_IP/g > $TMP_FOLDER/init-redis.sh
}

# Deploy the puppet master that will coordinate the configuration of the machines
function deploy_puppet_master() {
  task "Deploying puppet master"
  INITFILE=./initScripts/initPuppetMaster.sh
  OUTPUT=$(ec2-run-instances $IMAGE -t $SIZE_PUPPET --region $REGION --key $KEYS -g $GROUP --user-data-file $INITFILE)
  INSTANCE_ID=$(echo $OUTPUT|awk '{print $6}')
  PUPPET_MASTER_ID=$INSTANCE_ID
  wait_for $INSTANCE_ID
  extract_puppet_master_data $INSTANCE_ID
  create_init_scripts
  
  SLEEP_TIME=60
  log "Waiting $SLEEP_TIME s for the Puppet Master to be ready"
  sleep $SLEEP_TIME
}

function print_summary() {
    REDIS_IDS=${LAYER_IDS[redis]}
    AGENT_IDS=${LAYER_IDS[agent]}

    task "Printing Results"
    echo "PUPPET_MASTER=$PUPPET_MASTER_ID" > summary.popboxenv
    echo "REDIS_INSTANCES=$REDIS_IDS" >> summary.popboxenv
    echo "AGENT_INSTANCES=$AGENT_IDS" >> summary.popboxenv
    echo -e "\n\n"
    log "Puppet Master ips: External ($PM_OUT_IP), Internal ($PM_IN_IP)" >> summary.popboxenv
    log "Agent instances: $AGENT_IDS" >> summary.popboxenv
    log "Agent external ips: ${LAYER_OUT_IPS[agent]}" >> summary.popboxenv
    log "Agent internal ips: ${LAYER_IN_IPS[agent]}" >> summary.popboxenv
    log "Redis instances: $REDIS_IDS" >> summary.popboxenv
    log "Agent external ips: ${LAYER_OUT_IPS[redis]}" >> summary.popboxenv
    log "Agent internal ips: ${LAYER_IN_IPS[redis]}" >> summary.popboxenv
    cat summary.popboxenv
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
    for i in `seq 1 $REDIS_NUMBER`;
    do
      deploy_node $i "redis"
    done

    for i in `seq 1 $AGENT_NUMBER`;
    do
      deploy_node $i "agent"
    done   

    print_summary
  fi
}

function remove_vms() {
  SUMMARY=$1

  if [[ -z "$SUMMARY" ]]; then
    error "No summary provided. Nothing will be removed"
    exit 1
  fi

  task "Removing selected environment: $SUMMARY"

  PUPPET_MASTER_ID=$(cat $1 |grep PUPPET_MASTER| cut -d= -f2)
  REDIS_IDS=$(cat $1 |grep REDIS_INSTANCES|cut -d= -f2)
  AGENT_IDS=$(cat $1 |grep AGENT_INSTANCES|cut -d= -f2)

  log "Removing Puppet Master with id $PUPPET_MASTER_ID"
  ec2-terminate-instances --region $REGION $PUPPET_MASTER_ID

  for id in $REDIS_IDS; do
    log "Removing Redis instance $id"
    ec2-terminate-instances --region $REGION $id
  done

  for id in $AGENT_IDS; do
    log "Removing Popbox agent instance $id"
    ec2-terminate-instances --region $REGION $id
  done

}

# Check the first command line argument to execute the corresponding action.
function dispatch_actions() {
  case "$1" in 
    install)
	deploy_vm $2 $3 $4
    ;;
    remove)
        remove_vms $2
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

