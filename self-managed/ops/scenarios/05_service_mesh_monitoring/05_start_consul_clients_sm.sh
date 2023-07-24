#!/usr/bin/env bash

# ++-----------
# ||   05 - Start Consul clients and sidecar proxies (Service Mesh)
# ++------
header1 "Securely connect your services with Consul service mesh"

# ++-----------------+
# || Variables       |
# ++-----------------+

export STEP_ASSETS="${ASSETS}scenario/conf/"

export NODES_ARRAY=( "hashicups-db" "hashicups-api" "hashicups-frontend" "hashicups-nginx" )

# ++-----------------+
# || Begin           |
# ++-----------------+

# header1 "Starting Consul service mesh"

##########################################################
header2 "Generate catch all intention"

tee ${STEP_ASSETS}config-intentions-default-allow.hcl > /dev/null << EOF
Kind = "service-intentions"
Name = "*"
Sources = [
  {
    Name   = "*"
    Action = "allow"
  }
]
EOF

consul config write ${STEP_ASSETS}config-intentions-default-allow.hcl

##########################################################
header2 "Apply new Consul client confiugration"

for node in ${NODES_ARRAY[@]}; do
  NODE_NAME=${node}
  header3 "Modify service configuration for ${NODE_NAME}"
  
  log_debug "Copy service files into Consul configuration directory"
  remote_exec ${NODE_NAME} "cp ${CONSUL_CONFIG_DIR}svc/service_mesh/*.hcl ${CONSUL_CONFIG_DIR}"

  log "Reload Consul configuration"
  _agent_token=`cat ${STEP_ASSETS}secrets/acl-token-${NODE_NAME}.json | jq -r ".SecretID"`

  remote_exec ${NODE_NAME} "/usr/bin/consul reload -token=${_agent_token}"

done

##########################################################
header2 "Start sidecar proxies on client VMs"

for node in ${NODES_ARRAY[@]}; do
  NODE_NAME=${node}
  header3 "Start Envoy sidecar for ${NODE_NAME}"
  _agent_token=`cat ${STEP_ASSETS}secrets/acl-token-${NODE_NAME}.json | jq -r ".SecretID"`
  
  ## [crit] Remove before fly. Test with bootstrap token
  ## [debug] Test if still true
  # _agent_token=${CONSUL_HTTP_TOKEN}
  
  log_debug "Stop existing instances"
  _ENVOY_PID=`remote_exec ${NODE_NAME} "pidof envoy"`
  if [ ! -z ${_ENVOY_PID} ]; then
    remote_exec ${NODE_NAME} "sudo kill -9 ${_ENVOY_PID}"
  fi

  log "Start Envoy instance"
  remote_exec ${NODE_NAME} "/usr/bin/consul connect envoy \
                              -token=${_agent_token} \
                              -envoy-binary /usr/bin/envoy \
                              -sidecar-for ${NODE_NAME}-1 \
                              ${ENVOY_EXTRA_OPT} -- -l trace > /tmp/sidecar-proxy.log 2>&1 &"
done

##########################################################
header2 "Restart Services to listen on local interface"

for node in ${NODES_ARRAY[@]}; do
  NODE_NAME=${node}
  
  if [ "${NODE_NAME}" == "hashicups-nginx" ]; then
    log_warn "Not restarting ${NODE_NAME} to provide access"
    remote_exec ${NODE_NAME} "bash ~/start_service.sh mesh" > /dev/null 2>&1
  else
    log "Restarting service ${NODE_NAME}"
    remote_exec ${NODE_NAME} "bash ~/start_service.sh local" > /dev/null 2>&1
  fi
done

# log_err "Consul Token: ${CONSUL_HTTP_TOKEN}"


## Generate list of created files during scenario step
## The list is appended to the $LOG_FILES_CREATED file
get_created_files