#! /bin/bash

# ++-----------------+
# || Functions       |
# ++-----------------+

## todo: clean_env() 
## Cleans entire environment. Removes Infrastructure.
clean_env() {

  ########## ------------------------------------------------
  header1     "CLEANING PREVIOUS SCENARIO"
  ###### -----------------------------------------------

  #   # ## Remove custom scripts
  # rm -rf ${ASSETS}scripts/*

  # ## Remove certificates 
  # rm -rf ${ASSETS}secrets/*

  # ## Remove data 
  # rm -rf ${ASSETS}data/*

  # ## Remove logs
  # # rm -rf ${LOGS}/*
  
  # ## Unset variables
  # unset CONSUL_HTTP_ADDR
  # unset CONSUL_HTTP_TOKEN
  # unset CONSUL_HTTP_SSL
  # unset CONSUL_CACERT
  # unset CONSUL_CLIENT_CERT
  # unset CONSUL_CLIENT_KEY
}

# ++-----------------+
# || Variables       |
# ++-----------------+

## Scenario Library

## MARK: FLOW CRITICAL POINT !!! - Scenario PATHS configuration

## Refers to a workbench folder used by the script itself.
## In this folder all the dynamic files created explicitly for this scenario are 
## kept.
## This might end up being replaced by the scenario variable when the scenario 
## is present not sure we want this.
ASSETS="../assets/"

## Refers to the scenario library where the script looks for scenario files and 
## for the
SCENARIOS_FOLDER="./scenarios"


# --- GLOBAL VARS AND FUNCTIONS ---
## Logging, OS checks, networking ()
source scenarios/00_shared_functions.env
## Scenario related functions. Depends on 00_*.env. Not imported into provision.sh
source scenarios/10_scenario_functions.env
## Infrastructure related functions. Depends on 00_*.env. Not imported into provision.sh
source scenarios/20_infrastructure_functions.env


## Scenario specific environment. Generated dynamically.
## UNCHARTED: Currently the tool supports only single scenario running.
##              Only single scenario use cases are tested at this time of 
##              development. 
##  ~todo: Check PATHS for existence
## If scenario file does not exist the final script might not work.
## If this file does not exist we should fallback to local execution and print a 
## warning because the resulting scripts might not work as-is.

## The assets folder should contain a scenario specific asset collection. This 
## at the moment counts as default state detection (possibly not the only factor)
SCENARIO_OUTPUT_FOLDER="${ASSETS}scenario/"

# ## -todo Flow control...remove before fly
# ## Artificially generate a scenario file (check dry_run=false option)
# touch ${SCENARIO_OUTPUT_FOLDER}scenario_env.env
# ## Artificially populate a BASTION_HOST variable (check _RUN_LOCAL=false)
# BASTION_HOST="Bastion Host"

## Scenario state detection
# [[ -f "$1" ]] && source "$1"

## Infrastructure creation creates a "state file", named `scenario_env.env` with 
## variables required to locate and connect to the remote scenario. If the state 
## file is not present you are either trying to create one (via creating infra)
## or you are testing the content creation. When possible will reverse to 
## dry_run version of the function (produce output but don't apply scripts).
if [ -f "${SCENARIO_OUTPUT_FOLDER}scenario_env.env" ]; then

  source ../assets/scenario/scenario_env.env  

else
  _NO_ENV="true"
fi

if [ "${_NO_ENV}" == "true" ]; then

  ## If there is no environment definition the scenario files might be faulty
  ## Therefore it is better to not run them but just generate them for checks.
  _DRY_RUN="true"

else
  ## If the scenario is defined we need to determine wether the provision.sh
  ## script is being executed locally or needs a remote Bastion Host for running

  ## We made this flow automatic by checking on the BASTION_HOST env variable.
  ## The variable needs to be populated prior to the script execution to make 
  ## this choice valid.

  if [ -z "${BASTION_HOST}" ]; then
    ## If BASTION_HOST is not set it means we are running the script locally
    ## This is the case when the provision.sh script is being executed on
    ## the bastion host at the end of the infrastructure provision.
    log "Bastion Host is not defined. The script is going to be executed on this node."
    _RUN_LOCAL="true"
  else 
    log "Bastion Host is ${BASTION_HOST}. The script is going to be executed remotely."
    _RUN_LOCAL="false"
    ## In this case we also SSH based options to permit SSH connection to the
    ## Bastion Host.

    ## MARK: FLOW CRITICAL POINT !!! if this breaks connections will not work.
    ## This overrides the SSH_OPTS and SSH_CERT the were loaded from
    ## ../assets/scenario/scenario_env.env for the provision.sh workflow. 
    ## This only affects the certificate used to connect to the Bastion Host. 
    ## The SSH_CERT defined in ../assets/scenario/scenario_env.env will still be
    ## used when running the operate.sh script on BASTION_HOST.

    ## Automatically accept certificates of remote nodes and tries to connect 
    ## for 10 seconds.
    ## todo Make this on global variables since it should be used in any case
    SSH_OPTS="-o StrictHostKeyChecking=accept-new -o ConnectTimeout=10"

    ## This is how to locate SSH certificate on the Bation Host
    ## ~todo Parametrize cloud provider (or move tf_home one level up)
    SSH_CERT="../infrastructure/aws/certs/id_rsa.pem"

    ## If running the script from a remote machine we need to redefine the 
    ## working paths to make the scenario genration work properly.
    WORKDIR="../"
    ASSETS="${WORKDIR}assets/"

  fi


fi

# --------------------
# --- ENVIRONMENT ----
# --------------------

## Removing previous run scripts
rm -rf ${ASSETS}scenario/scripts 

## Comma separates string of prerequisites
PREREQUISITES="docker,wget,jq,grep,sed,tail,awk"

# ++-----------------+
# || Begin           |
# ++-----------------+

## Flow control
## Check parameters
if   [ "$1" == "clean" ]; then
  #  todo Clean environment. This should be executed before applying
  # a scenario (it would be nice to have idempotent scenarios apply)
  exit 0
elif [ "$1" == "operate" ]; then
  ########## ------------------------------------------------
  header1     "OPERATE SCENARIO"
  ###### -----------------------------------------------
  ## Generates scenario operate file and runs it on bastion host. 
  ## Scenario file is composed from the scenario folder and is going to be 
  ## located at ${ASSETS}scenario/scripts/operate.sh
  ## Uses functions defined at ${SCENARIOS}/10_scenario_functions.env

  ## 0 Clean existing environment
  ## todo check here for sw_clean or hw_clean
  ## For now the scenario should be safe enough to be ran multiple times on the 
  ## same host with similar output.
 
  ## Generate operate.sh script
  operate_dry $2
  ## Ececute operate.sh script
  execute_scenario_step "operate"

elif [ "$1" == "infra" ]; then
  ##  todo Spins up infrastructure for scenario. 
  ## Infrastructure files are located at ../infrastructure.
  ## ## Uses functions defined at ${SCENARIOS}/20_infrasteructure_functions.env
  exit 0
elif [ "$1" == "check" ]; then
  ##  todo Generates scenario check file and runs it on bastion host. 
  ## Scenario file is composed from the scenario folder and is going to be 
  ## located at ${ASSETS}scenario/scripts/check.sh
  ## Uses functions defined at ${SCENARIOS}/10_scenario_functions.env
  exit 0
elif [ "$1" == "solve" ]; then
  ## todo Generates scenario solution file and runs it on bastion host. 
  ## Scenario file is composed from the scenario folder and is going to be 
  ## located at ${ASSETS}scenario/scripts/solve.sh
  ## Uses functions defined at ${SCENARIOS}/10_scenario_functions.env
  exit 0
fi

## Clean environment
log "Cleaning Environment"
clean_env

########## ------------------------------------------------
header1     "PROVISIONING PREREQUISITES"
###### -----------------------------------------------

## Checking Prerequisites
log "Checking prerequisites..."
for i in `echo ${PREREQUISITES} | sed 's/,/ /g'` ; do
  prerequisite_check $i
done
