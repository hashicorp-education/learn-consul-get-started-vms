#!/usr/bin/env bash

# ++-----------
# ||   03 - Start Consul servers
# ++------
header1 "Deploy Consul on VMs"

# ++-----------------+
# || Variables       |
# ++-----------------+

## Variables from Scenario Environment Definition File
## ----------------------------------------------------- ##


## [ ] todo move parameters in 00_local_vars.env
## Supporting script configuration
## ----------------------------------------------------- ##
## Number of servers to spin up (3 or 5 recommended for production environment)
SERVER_NUMBER=${CONSUL_SERVER_NUMBER:-1}
## Define primary datacenter and domain for the sandbox Consul DC
DOMAIN=${CONSUL_DOMAIN:-"consul"}
DATACENTER=${CONSUL_DATACENTER:-"dc1"}

CONSUL_CONFIG_DIR="/etc/consul.d/"
CONSUL_DATA_DIR="/opt/consul/"

# export RETRY_JOIN="${CONSUL_RETRY_JOIN}"
export CONSUL_RETRY_JOIN
## Putting all the generated files for this step into a 'control-plane' folder
export STEP_ASSETS="${SCENARIO_OUTPUT_FOLDER}conf/"

# ++-----------------+
# || Begin           |
# ++-----------------+

##########################################################
header2 "Generate Consul server configuration"

## This needs to be exported here to work inside the script.
## [bug] [conf] Configuration generated does not work for different dc.domain
export CONSUL_DOMAIN=${DOMAIN}
export CONSUL_DATACENTER=${DATACENTER}
export CONSUL_SERVER_NUMBER=${SERVER_NUMBER}
export OUTPUT_FOLDER=${STEP_ASSETS}

export CONSUL_DNS_PORT="53"

## [ux-diff] [cloud provider] UX differs across different Cloud providers
if [ "${SCENARIO_CLOUD_PROVIDER}" == "docker" ]; then
  export CONSUL_DNS_PORT="53"

  set -x

  if [ ! -z "${INSTRUQT_PARTICIPANT_ID}" ]; then
    ## This means we are in an instruqt scenario
    export GRAFANA_URL="https://operator-3001-${INSTRUQT_PARTICIPANT_ID}.env.play.instruqt.com"
  fi

  set +x 

elif [ "${SCENARIO_CLOUD_PROVIDER}" == "aws" ]; then
  export CONSUL_DNS_PORT="8600"
elif [ "${SCENARIO_CLOUD_PROVIDER}" == "azure" ]; then
  export CONSUL_DNS_PORT="8600"
else 
  log_err "Cloud provider $SCENARIO_CLOUD_PROVIDER is unsupported...exiting."
  exit 245
fi

## [cmd] [script] generate_consul_server_config.sh
log -l WARN -t '[SCRIPT]' "Generate Consul server config"
execute_supporting_script "generate_consul_server_config.sh"

##########################################################
header3 "Copy configuration on Consul server nodes"

for i in `seq 0 "$((SERVER_NUMBER-1))"`; do

  ## [ux-diff] [cloud provider] UX differs across different Cloud providers
  if [ "${SCENARIO_CLOUD_PROVIDER}" == "docker" ]; then

    ## [mark] this thing is ugly. Debug and check paths
    log_debug  "Remove pre-existing configuration and stopping pre-existing Consul instances"
    remote_exec -o consul-server-$i "sudo rm -rf ${CONSUL_CONFIG_DIR}* && \
                                  sudo mkdir -p ${CONSUL_CONFIG_DIR} && \
                                  sudo chown 1000:1000 ${CONSUL_CONFIG_DIR} && \
                                  sudo chmod g+w ${CONSUL_CONFIG_DIR} && \
                                  sudo rm -rf ${CONSUL_DATA_DIR}* && \
                                  sudo mkdir -p ${CONSUL_DATA_DIR} && \
                                  sudo chown 1000:1000 ${CONSUL_DATA_DIR} && \
                                  sudo chmod g+w ${CONSUL_DATA_DIR}" 

  elif [ "${SCENARIO_CLOUD_PROVIDER}" == "aws" ]; then

    ## [mark] this thing is ugly. Debug and check paths
    log_debug  "Remove pre-existing configuration and stopping pre-existing Consul instances"
    remote_exec -o consul-server-$i "sudo rm -rf ${CONSUL_CONFIG_DIR}* && \
                                  sudo mkdir -p ${CONSUL_CONFIG_DIR} && \
                                  sudo chown consul: ${CONSUL_CONFIG_DIR} && \
                                  sudo chmod g+w ${CONSUL_CONFIG_DIR} && \
                                  sudo rm -rf ${CONSUL_DATA_DIR}* && \
                                  sudo mkdir -p ${CONSUL_DATA_DIR} && \
                                  sudo chown consul: ${CONSUL_DATA_DIR} && \
                                  sudo chmod g+w ${CONSUL_DATA_DIR}"

  elif [ "${SCENARIO_CLOUD_PROVIDER}" == "azure" ]; then

    ## [mark] this thing is ugly. Debug and check paths
    log_debug  "Remove pre-existing configuration and stopping pre-existing Consul instances"
    remote_exec -o consul-server-$i "sudo rm -rf ${CONSUL_CONFIG_DIR}* && \
                                  sudo mkdir -p ${CONSUL_CONFIG_DIR} && \
                                  sudo chown consul: ${CONSUL_CONFIG_DIR} && \
                                  sudo chmod g+w ${CONSUL_CONFIG_DIR} && \
                                  sudo rm -rf ${CONSUL_DATA_DIR}* && \
                                  sudo mkdir -p ${CONSUL_DATA_DIR} && \
                                  sudo chown consul: ${CONSUL_DATA_DIR} && \
                                  sudo chmod g+w ${CONSUL_DATA_DIR}"

  else 
    log_err "Cloud provider $SCENARIO_CLOUD_PROVIDER is unsupported...exiting."
    exit 245
  fi

  log_debug "Stopping Consul process on consul-server-$i"
  
  _CONSUL_PID=`remote_exec consul-server-$i 'pidof consul'`
    
  if [ ! -z "${_CONSUL_PID}" ]; then
  
    log_debug "Found Consul process with PID: ${_CONSUL_PID}. Stopping it. "
    COMMAND="sudo kill -9 ${_CONSUL_PID}"
    # log_trace -t "[COMM]" "${COMMAND}" 
    remote_exec consul-server-$i "$COMMAND"
  else
    log_trace "Consul process not running, nothing to clean."
  fi

  log "Copying Configuration on consul-server-$i"
  
  remote_copy consul-server-$i "${STEP_ASSETS}consul-server-$i/*" "${CONSUL_CONFIG_DIR}" 

done


##########################################################
header2 "Start Consul server"

for i in `seq 0 "$((SERVER_NUMBER-1))"`; do
  log "Start Consul process on consul-server-$i"
  
  ## [ux-diff] [cloud provider] UX differs across different Cloud providers
  if [ "${SCENARIO_CLOUD_PROVIDER}" == "docker" ]; then
    wait_for consul-server-$i
  fi

  remote_exec consul-server-$i \
    "/usr/bin/consul agent \
    -log-file=/tmp/consul-server-$i.${DATACENTER}.${DOMAIN} \
    -config-dir=${CONSUL_CONFIG_DIR} > /tmp/consul-server.log 2>&1 &" 


  sleep 1
done
##########################################################
header2 "Configure Consul CLI to interact with Consul server"

## Consul CLI Configuration
export CONSUL_HTTP_ADDR="https://consul-server-0:8443"
export CONSUL_HTTP_SSL=true
export CONSUL_CACERT="${STEP_ASSETS}secrets/consul-agent-ca.pem"
export CONSUL_TLS_SERVER_NAME="server.${DATACENTER}.${DOMAIN}"

header2 "Bootstrap ACLs"

for i in `seq 1 9`; do
  
  consul acl bootstrap --format json > ${STEP_ASSETS}secrets/acl-token-bootstrap.json 2> /dev/null;

  excode=$?

  if [ ${excode} -eq 0 ]; then
    break;
  else
    if [ $i -eq 9 ]; then
      log_err "Failed to bootstrap ACL system, exiting."
      exit 1
    else
      log_warn "ACL system not ready. Retrying...";
      sleep 5;
    fi
  fi

done
  log "ACL system bootstrapped"

## Consul CLI Configuration
export CONSUL_HTTP_TOKEN=`cat ${STEP_ASSETS}secrets/acl-token-bootstrap.json | jq -r ".SecretID"`

##########################################################
header2 "Create server tokens"

## [cmd] [script] generate_consul_server_tokens.sh
log -l WARN -t '[SCRIPT]' "Generate Consul server tokens"
execute_supporting_script "generate_consul_server_tokens.sh"

## Generate list of created files during scenario step
## The list is appended to the $LOG_FILES_CREATED file
get_created_files

## Generate environment file for Consul
## At this point the script resets the Consul environment file for the scwnario.
print_env consul > ${ASSETS}/scenario/env-consul.env 
