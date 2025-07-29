#!/usr/bin/env bash

# ++-----------------+
# || Variables       |
# ++-----------------+

export STEP_ASSETS="${SCENARIO_OUTPUT_FOLDER}conf/"

# ++-----------------+
# || Begin           |
# ++-----------------+

header1 "Register HashiCups services in Consul service mesh"

# ++-----------------+
# || Begin           |
# ++-----------------+

# OUTPUT_FOLDER=${STEP_ASSETS}global

OUTPUT_FOLDER=${STEP_ASSETS}

header2 "Generate global config files"

log "Remove pre-existing configuration files"

rm -rf ${OUTPUT_FOLDER}global
mkdir -p "${OUTPUT_FOLDER}global"

log "Generate files"

## [cmd] [script] generate_global_config_hashicups.sh
log -l WARN -t '[SCRIPT]' "Generate global Consul config for HashiCups"
execute_supporting_script "generate_global_config_hashicups.sh"

log "Apply configuration"

for i in `find ${STEP_ASSETS}global -name "*.hcl"`; do
  consul config write $i
done

header2 Register HashiCups services in Consul service mesh

NODES_ARRAY=( "hashicups-db" "hashicups-api" "hashicups-frontend" "hashicups-nginx" )

for node in "${NODES_ARRAY[@]}"; do

  header3 "Register service for ${node}"

  NUM="${node/-/_}""_NUMBER"
  
  for i in `seq ${!NUM}`; do

    export NODE_NAME="${node}-$((i-1))"
    
    log "Copy Configuration for ${NODE_NAME}"

    remote_copy ${NODE_NAME} "${STEP_ASSETS}${NODE_NAME}/svc/service_mesh/svc-${node}.hcl" "${CONSUL_CONFIG_DIR}"

    sleep 2

    # if [ "${ENABLE_SERVICE_MESH}" == "true" ]; then
    #   remote_exec ${NODE_NAME} "cp ${CONSUL_CONFIG_DIR}svc/service_mesh/*.hcl ${CONSUL_CONFIG_DIR}"
    # else
    #   remote_exec ${NODE_NAME} "cp ${CONSUL_CONFIG_DIR}svc/service_discovery/*.hcl ${CONSUL_CONFIG_DIR}"
    # fi

    # ## Reload is not necessary since we introduced auto_reload_config = true in the configuration
    # log "Reload Configuration for ${NODE_NAME}"
    # _agent_token=`cat ${STEP_ASSETS}secrets/acl-token-bootstrap.json | jq -r ".SecretID"`
    # remote_exec ${NODE_NAME} "/usr/bin/consul reload -token=${_agent_token}"

    log "Start Envoy sidecar-proxy for ${NODE_NAME}"

    log_debug "Stop existing instances"
    _ENVOY_PID=`remote_exec ${NODE_NAME} "pidof envoy"`
    if [ ! -z ${_ENVOY_PID} ]; then
      remote_exec ${NODE_NAME} "sudo kill -9 ${_ENVOY_PID}"
    fi

    log "Start Envoy instance"

    _agent_token=`cat ${STEP_ASSETS}secrets/acl-token-bootstrap.json | jq -r ".SecretID"`

    remote_exec ${NODE_NAME} "/usr/bin/consul connect envoy \
                              -token=${_agent_token} \
                              -envoy-binary /usr/bin/envoy \
                              -sidecar-for ${NODE_NAME} \
                              ${ENVOY_EXTRA_OPT} -- -l ${ENVOY_LOG_LEVEL} > /tmp/sidecar-proxy.log 2>&1 &"
  done
done

header2 "Restart HashiCups services to listen on localhost"

for node in "${NODES_ARRAY[@]}"; do

  header3 "Restart service for ${node}"

  NUM="${node/-/_}""_NUMBER"
  
  for i in `seq ${!NUM}`; do

    export NODE_NAME="${node}-$((i-1))"
    
    _start_param="--local"

    if [ "${node}" == "hashicups-nginx" ]; then
      log "HashiCups NGINX detected, restarting in Ingress mode"
      _start_param="--ingress"
    fi      

    log "Restart service with param ${_start_param} on ${NODE_NAME}"

    remote_exec ${NODE_NAME} "~/start_service.sh start ${_start_param}"

  done
done
