#!/bin/bash

. config.sh

# DEFINITIONS
####################################################################
TMP_FOLDER=/tmp
declare -A LAYER_IDS
declare -A LAYER_OUT_IPS
declare -A LAYER_IN_IPS
declare -A LAYER_NUMBER

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
  echo -e "\nUsage:"
  echo -e "\tdeploy.sh install <branch-name> (<node-type> <node-number)+\n"
  echo -e "\t\tDeploys an environment consisting of a Puppet master and a variable"
  echo -e "\t\tnumber of nodes, specified in the command line as any number of pairs"
  echo -e "\t\t<node-type> <node-number>. The source code will be downloaded from"
  echo -e "\t\tthe selected branch of the configured GIT repository\n"
  echo -e "\tdeploy.sh uninstall <summary_file>\n"
  echo -e "\t\tUninstall an environment from a previously saved summary file\n"
  echo -e "\tdeploy.sh add <summary_file> <node_type>\n"
  echo -e "\t\tAdds a new node of the given type to the given environment\n"
  echo -e "\tdeploy.sh remove <summary_file> <node_type>\n"
  echo -e "\t\tRemoves a node of the given type from the given environment\n"
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

# Extract the Puppet Master data from its instance ID in EC2
function extract_puppet_master_data() {
  INSTANCE_ID=$1
  OUTPUT=$(ec2-describe-instances --region $REGION $INSTANCE_ID)
  PM_OUT_IP=$(echo $OUTPUT | awk '{print $18}')
  PM_IN_IP=$(echo $OUTPUT | awk '{print $19}')
  log "Puppet Master: InternalIP($PM_IN_IP), ExternalIP($PM_OUT_IP)"
}

function create_init_scripts() {
  for nodename in $LAYERS; do
    cat initScripts/init-node.sh | sed s/@PM_IP/$PM_IN_IP/g | sed s/@NODE_TAG/$nodename/g > $TMP_FOLDER/init-$nodename.sh
  done
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
  
  SLEEP_TIME=45
  log "Waiting $SLEEP_TIME s for the Puppet Master to be ready"
  sleep $SLEEP_TIME
}

# Check all the EC2 data of each isntance and print it
function print_instances() {

    log "Instance summary"

    for instance in $1; do
      log "Instance id: $instance"

      OUTPUT=$(ec2-describe-instances --region $REGION $instance | grep INSTANCE)
        
      log "External name: $(echo $OUTPUT  | awk '{print $4}')"
      log "Internal name: $(echo $OUTPUT  | awk '{print $5}')"
      log "External ip: $(echo $OUTPUT  | awk '{print $14}')"
      log "Internal ip: $(echo $OUTPUT  | awk '{print $15}')"
      echo -e "\n"
    done
}

function print_summary() {
    task "Printing Results"
    
    TARGET_FILE=summary.tdafenv

    echo "* Environment summary:" > $TARGET_FILE

    TOTAL_INSTANCES=$PUPPET_MASTER_ID
    for nodename in $LAYERS; do
      TOTAL_INSTANCES+=" ${LAYER_IDS[$nodename]}"
      echo "${nodename}_layer=${LAYER_IDS[$nodename]}" >> $TARGET_FILE
    done

    echo "TOTAL_INSTANCES=$TOTAL_INSTANCES" >> $TARGET_FILE
    echo "PUPPET_MASTER=" $PM_IN_IP >> $TARGET_FILE
    
    log "Puppet Master ips: External ($PM_OUT_IP), Internal ($PM_IN_IP)"

    print_instances "$TOTAL_INSTANCES"
}

# Deploy an instance of the full stack. The number of Popbox Agents and 
# Redis instances will be taken from the config files, unless overriden
# by the input parameters.
function deploy_vm () {
  if [[ -n "$1" ]]; then
    GIT_BRANCH=$1
  fi;

  task "Deploying branch $GIT_BRANCH with ${LAYER_NUMBER[agent]} Agents connected to ${LAYER_NUMBER[redis]} Redis"

  deploy_puppet_master

  for nodename in $LAYERS; do
    for i in `seq 1 ${LAYER_NUMBER[$nodename]}`;
    do
      deploy_node $i $nodename
    done
  done

  print_summary
}

# Check the file passed as a parameter is a valid environment file
function check_environment() {
  echo $1 |egrep ".*tdafenv" > /dev/null
  
  if [[ $? = 1 ]]; then
    error "Extension not recognized. *.tdafenv expected."
    exit 1
  fi

  cat $1 |egrep "TOTAL_INSTANCES" > /dev/null

  if [[ $? = 1 ]]; then
    error "Instance IDs not found. Invalid environment format."
    exit 1
  fi
}

# Remove all the instances from a previously saved environment summary
function remove_vms() {
  SUMMARY=$1

  check_environment $SUMMARY

  if [[ -z "$SUMMARY" ]]; then
    error "No summary provided. Nothing will be removed"
    exit 1
  fi

  
  task "Removing selected environment: $SUMMARY"

  TOTAL_IDS=$(cat $1 |grep TOTAL_INSTANCES| cut -d= -f2)

  for id in $TOTAL_IDS; do
    log "Removing instance $id"
    ec2-terminate-instances --region $REGION $id
  done

}

# Add a new node to the environment passed as te first parameter. The second
# parameter specifies the type of node to deploy.
function add_node() {

  if [[ -z "$1" ]]; then
    error "No environment was provided. Nothing will be added"
    exit 1
  fi

  if [[ -z "$2" ]]; then
    error "Node type missing. Nothing will be added"
    exit 1
  fi

  task "Adding node type $2 to environment $1"

  # Find the Puppet Master ID to prepare the init_scripts
  PM_IN_IP=$(cat summary.tdafenv |grep PUPPET_MASTER|awk '{print $2}')
  LAYERS=$2
  create_init_scripts

  deploy_node 1 $2

  sed -i "s/TOTAL_INSTANCES.*/& ${LAYER_IDS[$2]}/g" $1
  sed -i "s/$2_layer.*/& ${LAYER_IDS[$2]}/g" $1  
}

function remove_node() {

  if [[ -z "$1" ]]; then
    error "No environment was provided. Nothing will be removed"
    exit 1
  fi

  if [[ -z "$2" ]]; then
    error "Node type missing. Nothing will be removed"
    exit 1
  fi

  task "Removing node type $2 from environment $1"
}

# Extract the parameters from the command line to decide which modules to deploy
function extract_parameters() {

  if [[ $(($# % 2)) = 1 ]]; then
    error "Wrong number of parameters, each node should have its node number"
    exit 1
  fi

  if [[ $# < 4 ]]; then
    error "Syntax error: at least one layer has to be specified"
    exit 1
  fi

  ARRAY=(${@})
  ELEMENTS=${#ARRAY[@]}

  LAYERS=""
  for (( i = 2; i < ${ELEMENTS}; i=i+2 )); do
    LAYERS+="${ARRAY[$i]} "
    LAYER_NUMBER[${ARRAY[$i]}]=${ARRAY[$(($i+1))]}
  done
}

# Check the first command line argument to execute the corresponding action.
function dispatch_actions() {
  case "$1" in 
    install)
        extract_parameters $@
	deploy_vm $2
    ;;
    uninstall)
        remove_vms $2
    ;;
    add)
        add_node $2 $3
    ;;
    remove)
        remove_node $2 $3
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
dispatch_actions $@

task "All actions finished\n"

