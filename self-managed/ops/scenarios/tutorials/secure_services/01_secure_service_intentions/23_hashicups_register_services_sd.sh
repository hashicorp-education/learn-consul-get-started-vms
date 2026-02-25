#!/usr/bin/env bash

# ++-----------------+
# || Variables       |
# ++-----------------+

export STEP_ASSETS="${SCENARIO_OUTPUT_FOLDER}conf/"

# CONSUL_LOG_LEVEL="DEBUG"

# ++-----------------+
# || Begin           |
# ++-----------------+

header1 "Register Consul services for HashiCups"

# export NODES_ARRAY=( "hashicups-db" "hashicups-api" "hashicups-frontend" "hashicups-nginx" )
NODES_ARRAY=( "hashicups-db" "hashicups-api" "hashicups-frontend" "hashicups-nginx" )

for node in "${NODES_ARRAY[@]}"; do

  header2 "Register the ${node} service"

  NUM="${node/-/_}""_NUMBER"
  
  for i in `seq ${!NUM}`; do

    export NODE_NAME="${node}-$((i-1))"

    header3 "Register service on ${NODE_NAME}"
    
    log "Create service configuration."

    mkdir -p "${STEP_ASSETS}${NODE_NAME}"

    # export SVC_TAGS="\"inst_$i\""
    export SVC_TAGS="\"v1\""

    consul acl token create -description="SVC ${node} token" --format json -service-identity="${node}" > ${STEP_ASSETS}secrets/acl-token-svc-${NODE_NAME}.json

    export CONSUL_AGENT_TOKEN=`cat ${STEP_ASSETS}secrets/acl-token-svc-${NODE_NAME}.json | jq -r ".SecretID"`

    ## [cmd] [script] generate_hashicups_service_config.sh
    ## [ ] move service definition map outside
    log -l WARN -t '[SCRIPT]' "Generate HashiCups service config"
    execute_supporting_script "generate_hashicups_service_config.sh"

    log "Copy Configuration"

    remote_copy ${NODE_NAME} "${STEP_ASSETS}${NODE_NAME}/svc" "${CONSUL_CONFIG_DIR}"
    remote_exec ${NODE_NAME} "cp ${CONSUL_CONFIG_DIR}svc/service_discovery/svc-${node}.hcl ${CONSUL_CONFIG_DIR}svc.hcl"

  done
done

