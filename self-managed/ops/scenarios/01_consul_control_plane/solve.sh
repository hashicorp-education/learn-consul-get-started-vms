#!/usr/bin/env bash

# ++-----------------+
# || Variables       |
# ++-----------------+

## Variables needed to make the script indipendent.
export CONSUL_RETRY_JOIN
CONSUL_CONFIG_DIR="/etc/consul.d/"
CONSUL_DATA_DIR="/opt/consul/"

## Variables needed for this step.
export STEP_ASSETS="${ASSETS}scenario/conf/"
export NODES_ARRAY=( "hashicups-db" "hashicups-api" "hashicups-frontend" "hashicups-nginx" )

# ++-----------------+
# || Begin           |
# ++-----------------+

header1 "Starting Consul client agents"

# log "Cleaning previous configfuration assets generated"
# for node in ${NODES_ARRAY[@]}; do
#   rm -rf ${STEP_ASSETS}${node}
# done

##########################################################
header2 "Generate Consul clients configuration"

for node in ${NODES_ARRAY[@]}; do
  export NODE_NAME=${node}
  # export CONSUL_RETRY_JOIN
  header3 "Generate Consul client configuration for ${NODE_NAME}"

  ## [cmd] [script] generate_consul_client_config.sh
  log "[EXTERNAL SCRIPT] - Generate Consul config"  
  execute_supporting_script "generate_consul_client_config.sh"

  log "Generate client tokens"

  tee ${STEP_ASSETS}acl-policy-${NODE_NAME}.hcl > /dev/null << EOF
# Allow the service and its sidecar proxy to register into the catalog.
# service_prefix "${NODE_NAME}" {
#     policy = "write"
# }

service "${NODE_NAME}" {
    policy = "write"
}

service "${NODE_NAME}-sidecar-proxy" {
    policy = "write"
}

node_prefix "" {
    policy = "read"
}

# Allow the agent to register its own node in the Catalog and update its network coordinates
node "${NODE_NAME}" {
  policy = "write"
}

# Allows the agent to detect and diff services registered to itself. This is used during
# anti-entropy to reconcile difference between the agents knowledge of registered
# services and checks in comparison with what is known in the Catalog.
service_prefix "" {
  policy = "read"
}

# Allow the agent to reload configuration
agent "${NODE_NAME}" {
  policy = "write"
}
agent_prefix "" {
  policy = "read"
}
EOF
  
  consul acl policy create -name "acl-policy-${NODE_NAME}" -description 'Policy for service node' -rules @${STEP_ASSETS}acl-policy-${NODE_NAME}.hcl  > /dev/null 2>&1

  consul acl token create -description "${NODE_NAME} - Agent token" -policy-name acl-policy-${NODE_NAME} --format json > ${STEP_ASSETS}secrets/acl-token-${NODE_NAME}.json 2> /dev/null

  DNS_TOK=`cat ${STEP_ASSETS}secrets/acl-token-dns.json | jq -r ".SecretID"`
  AGENT_TOKEN=`cat ${STEP_ASSETS}secrets/acl-token-${NODE_NAME}.json | jq -r ".SecretID"` 

  ## [crit] figure before fly - testing with management token
  ## [debug] Test if still true
  # DNS_TOK=${CONSUL_HTTP_TOKEN}
  # AGENT_TOKEN=${CONSUL_HTTP_TOKEN}

  tee ${STEP_ASSETS}${NODE_NAME}/agent-acl-tokens.hcl > /dev/null << EOF
acl {
  tokens {
    agent  = "${AGENT_TOKEN}"
    default  = "${DNS_TOK}"
    config_file_service_registration = "${AGENT_TOKEN}"
  }
}
EOF

  ## Adding the token to the service definition files for anti-entropy
  ## [warn] [CHECK BEHAVIOR]: Why is config_file_service_registration not enforced?
  ## Is it safe enough to set default = agent ? After all the client is not 
  ## exposing anything sensitive.
  export _agent_token=${AGENT_TOKEN}

  ## [cmd] [script] generate_consul_service_config.sh
  ## [ ] Move service definition map outside
  log "[EXTERNAL SCRIPT] - Generate services config"
  execute_supporting_script "generate_consul_service_config.sh"

  unset _agent_token

  ## This step is Service Discovery so we copy the relevant service definition 
  ## into Consul configuration
  cp ${STEP_ASSETS}${NODE_NAME}/svc/service_discovery/*.hcl "${STEP_ASSETS}${NODE_NAME}"

  log "Clean remote node"
  set -x
  remote_exec ${NODE_NAME} "sudo rm -rf ${CONSUL_CONFIG_DIR}* && \
                            sudo rm -rf ${CONSUL_DATA_DIR}* && \
                            sudo chmod g+w ${CONSUL_DATA_DIR}"
set +x 
  ## Stop already running Consul processes
  _CONSUL_PID=`remote_exec ${NODE_NAME} "pidof consul"`
  if [ ! -z "${_CONSUL_PID}" ]; then
    remote_exec ${NODE_NAME} "sudo kill -9 ${_CONSUL_PID}"
  fi

  ## Stop already running Envoy processes (helps idempotency)
  _ENVOY_PID=`remote_exec ${NODE_NAME} "pidof envoy"`
  if [ ! -z "${_ENVOY_PID}" ]; then
    remote_exec ${NODE_NAME} "sudo kill -9 ${_ENVOY_PID}"
  fi

  log "Copy configuration on client nodes"
  remote_copy ${NODE_NAME} "${STEP_ASSETS}${NODE_NAME}/*" "${CONSUL_CONFIG_DIR}" 
done

##########################################################
header2 "Start Consul client agents"

for node in ${NODES_ARRAY[@]}; do
  export NODE_NAME=${node}
  log "Starting consul process on ${NODE_NAME}"
  remote_exec ${NODE_NAME} \
    "/usr/bin/consul agent \
    -log-file=/tmp/consul-client \
    -config-dir=${CONSUL_CONFIG_DIR} > /tmp/consul-client.log 2>&1 &" 

  sleep 1

done

