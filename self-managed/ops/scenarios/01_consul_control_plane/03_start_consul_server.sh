#!/usr/bin/env bash

# ++-----------------+
# || Variables       |
# ++-----------------+

## Variables from Scenario Environment Definition File
## ----------------------------------------------------- ##


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
export STEP_ASSETS="${ASSETS}scenario/conf/"

# ++-----------------+
# || Begin           |
# ++-----------------+

header1 "Starting Consul server"

##########################################################
header2 "Generate Consul servers configuration"

## This needs to be exported here to work inside the script.
## [bug] [conf] Configuration generated does not work for different dc.domain
export CONSUL_DOMAIN=${DOMAIN}
export CONSUL_DATACENTER=${DATACENTER}
export CONSUL_SERVER_NUMBER=${SERVER_NUMBER}

## [cmd] [script] generate_consul_server_config.sh
execute_supporting_script "generate_consul_server_config.sh"

##########################################################
header2 "Copy Consul servers configuration files"

## [x] make all servers discoverable from bastion host
for i in `seq 0 "$((SERVER_NUMBER-1))"`; do

  ## [mark] this thing is ugly. Debug and check paths
  log "Remove pre-existing configuration and stopping pre-existing Consul instances"
  remote_exec consul-server-$i "sudo rm -rf ${CONSUL_CONFIG_DIR}* && \
                                  sudo mkdir -p ${CONSUL_CONFIG_DIR} && \
                                  sudo chown consul: ${CONSUL_CONFIG_DIR} && \
                                  sudo chmod g+w ${CONSUL_CONFIG_DIR} && \
                                  sudo rm -rf ${CONSUL_DATA_DIR}* && \
                                  sudo mkdir -p ${CONSUL_DATA_DIR} && \
                                  sudo chown consul: ${CONSUL_DATA_DIR} && \
                                  sudo chmod g+w ${CONSUL_DATA_DIR}"
  
  _CONSUL_PID=`remote_exec consul-server-$i "pidof consul"`
  if [ ! -z ${_CONSUL_PID} ]; then
    remote_exec consul-server-$i "sudo kill -9 ${_CONSUL_PID}"
  fi
  
  log "Copying Configuration on consul-server-$i"
  remote_copy consul-server-$i "${STEP_ASSETS}consul-server-$i/*" "${CONSUL_CONFIG_DIR}" 

done


##########################################################
header2 "Start Consul"

## ~todo make all servers discoverable from bastion host
for i in `seq 0 "$((SERVER_NUMBER-1))"`; do
  log "Start Consul process on consul-server-$i"
  
  remote_exec consul-server-$i \
    "/usr/bin/consul agent \
    -log-file=/tmp/consul-server-$i.${DATACENTER}.${DOMAIN} \
    -config-dir=${CONSUL_CONFIG_DIR} > /tmp/consul-server.log 2>&1 &" 

  sleep 1
done

##########################################################
header2 "Configure ACL"

## Consul CLI Configuration
export CONSUL_HTTP_ADDR="https://consul-server-0:8443"
export CONSUL_HTTP_SSL=true
export CONSUL_CACERT="${STEP_ASSETS}secrets/consul-agent-ca.pem"
export CONSUL_TLS_SERVER_NAME="server.${DATACENTER}.${DOMAIN}"

log "ACL Bootstrap"

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

## Consul CLI Configuration
export CONSUL_HTTP_TOKEN=`cat ${STEP_ASSETS}secrets/acl-token-bootstrap.json | jq -r ".SecretID"`

##########################################################
header2 "Configure servers token"

## [cmd] [script] generate_consul_server_tokens.sh
execute_supporting_script "generate_consul_server_tokens.sh"
