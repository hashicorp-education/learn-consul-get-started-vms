#!/usr/bin/env bash

# ++-----------------+
# || Variables       |
# ++-----------------+

export STEP_ASSETS="${SCENARIO_OUTPUT_FOLDER}conf/"

# ++-----------------+
# || Begin           |
# ++-----------------+

header1 "Configure ing DNS for HashiCups Client nodes"

# log "Change DNS for API Gateways"

# for i in `seq ${api_gw_NUMBER}`; do
#   NODE_NAME="gateway-api-$((i-1))"
#   remote_exec -o ${NODE_NAME} "${DNS_CHANGE_COMMAND}"
# done 

# log "Change DNS for Mesh Gateways"

# for i in `seq ${mesh_gw_NUMBER}`; do
#   NODE_NAME="gateway-mesh-$((i-1))"
#   remote_exec -o ${NODE_NAME} "${DNS_CHANGE_COMMAND}"
# done 

# log "Change DNS for Terminating Gateways"

# for i in `seq ${term_gw_NUMBER}`; do
#   NODE_NAME="gateway-terminating-$((i-1))"
#   remote_exec -o ${NODE_NAME} "${DNS_CHANGE_COMMAND}"
# done 

# log "Change DNS for Consul ESM nodes"

# for i in `seq ${consul_esm_NUMBER}`; do
#   NODE_NAME="consul-esm-$((i-1))"
#   remote_exec -o ${NODE_NAME} "${DNS_CHANGE_COMMAND}"
# done 

# export NODES_ARRAY=( "hashicups-db" "hashicups-api" "hashicups-frontend" "hashicups-nginx" )
NODES_ARRAY=( "hashicups-db" "hashicups-api" "hashicups-frontend" "hashicups-nginx" )

log "Change DNS for Consul Service Nodes"

for node in "${NODES_ARRAY[@]}"; do

  NUM="${node/-/_}""_NUMBER"
  
  for i in `seq ${!NUM}`; do

    NODE_NAME="${node}-$((i-1))"
    remote_exec -o ${NODE_NAME} "${DNS_CHANGE_COMMAND}"
  done
done
