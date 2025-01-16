#!/usr/bin/env bash

# ++-----------------+
# || Variables       |
# ++-----------------+

export STEP_ASSETS="${SCENARIO_OUTPUT_FOLDER}conf/"

# ++-----------------+
# || Begin           |
# ++-----------------+

header1 "Configure ing DNS for API gateway nodes"

for i in `seq ${api_gw_NUMBER}`; do

  NODE_NAME="gateway-api-$((i-1))"

  log "Change DNS configuration for ${NODE_NAME}"

  remote_exec -o ${NODE_NAME} "${DNS_CHANGE_COMMAND}"

done 

