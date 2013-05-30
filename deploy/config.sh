
# Amazon EC2 configuration
#############################################
SIZE_AGENT=t1.micro
SIZE_REDIS=t1.micro
SIZE_PUPPET=t1.micro
REGION=eu-west-1
KEYS=dani-keys
GROUP=apigeetest
INITFILE=initMinimal.sh
IMAGE=ami-7e636a0a

# Default Architecture
############################################

# Number of Popbox Agents. If 0, both the redis and the agents
# will be installed in the same machine, and the redis parameter
# will be ignored.
AGENT_NUMBER=0

# Number of Redis instances to be deployed. All the instances will
# be deployed in a master/slave configuration
REDIS_NUMBER=1

# General
############################################

# Git repository from where the code will be retrieved
GIT_REPOSITORY=https://github.com/dmoranj/PopBox.git

# The code branch that will be downloaded and installed in the agents
GIT_BRANCH=deployment
