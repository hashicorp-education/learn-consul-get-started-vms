#!/usr/bin/env bash

# ++-----------------+
# || Variables       |
# ++-----------------+

export STEP_ASSETS="${SCENARIO_OUTPUT_FOLDER}conf/"

# ++-----------------+
# || Begin           |
# ++-----------------+

header1 "Configuring DNS change command for Consul clients"

log_info "Found cloud povider: ${SCENARIO_CLOUD_PROVIDER}"

## [ux-diff] [cloud provider] UX differs across different Cloud providers 
if [ "${SCENARIO_CLOUD_PROVIDER}" == "docker" ]; then

  CONSUL_DNS_IP=`dig +short consul-server-0`
  DNS_CHANGE_COMMAND="echo search service.${CONSUL_DATACENTER}.${CONSUL_DOMAIN} node.${CONSUL_DATACENTER}.${CONSUL_DOMAIN} > /tmp/resolv && \
  echo nameserver ${CONSUL_DNS_IP} >> /tmp/resolv && \
  cat /etc/resolv.conf >> /tmp/resolv && \
  sudo sh -c 'cat /tmp/resolv > /etc/resolv.conf'"

elif [ "${SCENARIO_CLOUD_PROVIDER}" == "aws" ]; then
  
  DNS_CHANGE_COMMAND="echo [Resolve] > /tmp/resolved.conf && \
  echo DNS=127.0.0.1:8600 >> /tmp/resolved.conf && \
  echo DNSSEC=false >> /tmp/resolved.conf && \
  echo 'Domains=~service.""${CONSUL_DOMAIN}"" ~node.""${CONSUL_DOMAIN}"" ~.' >> /tmp/resolved.conf && \
  sudo cp /tmp/resolved.conf /etc/systemd/resolved.conf && \
  sudo systemctl restart systemd-resolved && \
  sudo mv /etc/resolv.conf /tmp/resolv.conf.old && \
  sudo ln -s /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf && \
  echo 'make_resolv_conf() { : ; }' > /tmp/nodnsupdate && \
  chmod +x /tmp/nodnsupdate && \
  sudo cp /tmp/nodnsupdate /etc/dhcp/dhclient-enter-hooks.d/nodnsupdate"

elif [ "${SCENARIO_CLOUD_PROVIDER}" == "azure" ]; then
  
  DNS_CHANGE_COMMAND="echo [Resolve] > /tmp/resolved.conf && \
  echo DNS=127.0.0.1:8600 >> /tmp/resolved.conf && \
  echo DNSSEC=false >> /tmp/resolved.conf && \
  echo 'Domains=~service.""${CONSUL_DOMAIN}"" ~node.""${CONSUL_DOMAIN}"" ~.' >> /tmp/resolved.conf && \
  sudo cp /tmp/resolved.conf /etc/systemd/resolved.conf && \
  sudo systemctl restart systemd-resolved && \
  sudo mv /etc/resolv.conf /tmp/resolv.conf.old && \
  sudo ln -s /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf"

  # sudo resolvectl dns 2 127.0.0.1:8600
  # sudo resolvectl domain 2 consul

else

  log_err "Cloud provider $SCENARIO_CLOUD_PROVIDER is unsupported...exiting."

  exit 245
fi

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

# # export NODES_ARRAY=( "hashicups-db" "hashicups-api" "hashicups-frontend" "hashicups-nginx" )
# NODES_ARRAY=( "hashicups-db" "hashicups-api" "hashicups-frontend" "hashicups-nginx" )

# log "Change DNS for Consul Service Nodes"

# for node in "${NODES_ARRAY[@]}"; do

#   NUM="${node/-/_}""_NUMBER"
  
#   for i in `seq ${!NUM}`; do

#     NODE_NAME="${node}-$((i-1))"
#     remote_exec -o ${NODE_NAME} "${DNS_CHANGE_COMMAND}"
#   done
# done
