#!/usr/bin/env bash

# ++-----------------+
# || Functions       |
# ++-----------------+
## Prints a line on stdout prepended with date and time

_log() {

  local _MSG="${@}"

  if [ "${PREPEND_DATE}" == true ]; then 
    _MSG="[$(date +"%Y-%d-%d %H:%M:%S")] -- ""${_MSG}"
  fi

  if [ "${COLORED_OUTPUT}" == true ]; then 
    echo -e "\033[1m${_MSG}\033[0m"
  else
    echo -e "${_MSG}"
  fi
}

_header() {

  local _MSG="[`basename $0`] - ${@}"
  local _DATE="[$(date +"%Y-%d-%d %H:%M:%S")] "

  if [ ! "${PREPEND_DATE}" == true ]; then 
    _DATE=""
  fi

  if [ "${COLORED_OUTPUT}" == true ]; then 
    echo -e "\033[1m${_DATE}\033[1m\033[33m${_MSG}\033[0m"
  else
    echo -e "${_DATE}${_MSG}"
  fi
}

_log_err() {

  if [ "${COLORED_OUTPUT}" == true ]; then 
    DEC_ERR="\033[1m\033[31m[ERROR] \033[0m\033[1m"
  else
    DEC_ERR="[ERROR] "
  fi

  _log "${DEC_ERR}${@}"  
}

_log_warn() {
  
  if [ "${COLORED_OUTPUT}" == true ]; then 
    DEC_WARN="\033[1m\033[33m[WARN] \033[0m\033[1m"
  else
    DEC_WARN="[WARN] "
  fi
  
  _log "${DEC_WARN}${@}"  
}


# ++-----------------+
# || Parameters      |
# ++-----------------+

## If colored output is not disabled by default the logs are colored.
COLORED_OUTPUT=${COLORED_OUTPUT:-"true"}
PREPEND_DATE=${PREPEND_DATE:-"true"}

## Check parameters configuration

CONSUL_DATACENTER=${CONSUL_DATACENTER:-"dc1"}
CONSUL_DOMAIN=${CONSUL_DOMAIN:-"consul"}
CONSUL_SERVER_NUMBER=${CONSUL_SERVER_NUMBER:-1}
CONSUL_HTTPS_PORT=${CONSUL_HTTPS_PORT:-"8443"}

OUTPUT_FOLDER=${OUTPUT_FOLDER:-"${STEP_ASSETS}"}

# ++-----------------+
# || Begin           |
# ++-----------------+

_header "- Generate Consul server tokens"

_log ""
_log "+ --------------------"
_log "| Parameter Check"
_log "+ --------------------"

_log_warn "Script is running with the following values"
_log_warn "----------"
_log_warn "CONSUL_DATACENTER = ${CONSUL_DATACENTER}"
_log_warn "CONSUL_DOMAIN = ${CONSUL_DOMAIN}"
_log_warn "CONSUL_SERVER_NUMBER = ${CONSUL_SERVER_NUMBER:-1}"
_log_warn "----------"

_log_warn "Generated configuration will be placed under:"
_log_warn "OUTPUT_FOLDER = ${OUTPUT_FOLDER:-"${STEP_ASSETS}"}"
_log_warn "----------"

## Check mandatory variables 
[ -z "$CONSUL_HTTP_TOKEN" ] && _log_err "Mandatory parameter: CONSUL_HTTP_TOKEN not set."  && exit 1
[ -z "$OUTPUT_FOLDER" ]     && _log_err "Mandatory parameter: OUTPUT_FOLDER not set."      && exit 1

_log ""
_log "+ --------------------"
_log "| Prepare folder"
_log "+ --------------------"

## todo Clean files 
## (at this point cleaning is made by previous scripts but might make sense locally)

_log ""
_log "+ --------------------"
_log "| Create Consul ACL policies and tokens"
_log "+ --------------------"

_log " - Define policies"

_log "   - [ acl-policy-dns.hcl ]"
tee ${OUTPUT_FOLDER}acl-policy-dns.hcl > /dev/null << EOF
# -----------------------------+
# acl-policy-dns.hcl           |
# -----------------------------+

node_prefix "" {
  policy = "read"
}
service_prefix "" {
  policy = "read"
}
# only needed if using prepared queries
query_prefix "" {
  policy = "read"
}
# needed for prometheus metrics
agent_prefix ""
{
  policy = "read"
}
EOF

_log "   - [ acl-policy-server-node ]"
tee ${OUTPUT_FOLDER}acl-policy-server-node.hcl > /dev/null << EOF
# -----------------------------+
# acl-policy-server-node.hcl   |
# -----------------------------+

node_prefix "consul-server" {
  policy = "write"
}
EOF


_log " - Configure CLI to communicate with Consul"

## [ ] Make CONSUL_HTTP_ADDR mandatory from outside 
export CONSUL_HTTP_ADDR="https://consul-server-0:${CONSUL_HTTPS_PORT}"
export CONSUL_HTTP_SSL=true
export CONSUL_CACERT="${OUTPUT_FOLDER}secrets/consul-agent-ca.pem"
export CONSUL_TLS_SERVER_NAME="server.${CONSUL_DATACENTER}.${CONSUL_DOMAIN}"
export CONSUL_HTTP_TOKEN=${CONSUL_HTTP_TOKEN}

_log " - Create Consul ACL policies"

consul acl policy create -name 'acl-policy-dns' -description 'Policy for DNS endpoints' -rules @${OUTPUT_FOLDER}acl-policy-dns.hcl  > /dev/null 2>&1
consul acl policy create -name 'acl-policy-server-node' -description 'Policy for Server nodes' -rules @${OUTPUT_FOLDER}acl-policy-server-node.hcl  > /dev/null 2>&1

_log " - Create Consul ACL tokens"

consul acl token create -description 'DNS - Default token' -policy-name acl-policy-dns --format json > ${OUTPUT_FOLDER}secrets/acl-token-dns.json 2> /dev/null

DNS_TOK=`cat ${OUTPUT_FOLDER}secrets/acl-token-dns.json | jq -r ".SecretID"` 

for i in `seq 0 "$((CONSUL_SERVER_NUMBER-1))"`; do
  
  pushd "${OUTPUT_FOLDER}secrets"  > /dev/null 2>&1

  export CONSUL_HTTP_ADDR="https://consul-server-$i:${CONSUL_HTTPS_PORT}"
  export CONSUL_CACERT="./consul-agent-ca.pem"

  consul acl token create -description "consul-server-$i" -policy-name acl-policy-server-node  --format json > ./consul-server-$i-acl-token.json 2> /dev/null

  SERV_TOK=`cat ./consul-server-$i-acl-token.json | jq -r ".SecretID"`

  _log ""
  _log "   - Set tokens for consul-server-$i"

  consul acl set-agent-token agent ${SERV_TOK}
  consul acl set-agent-token default ${DNS_TOK}

  popd > /dev/null 2>&1

done

export CONSUL_HTTP_ADDR="https://consul-server-0:${CONSUL_HTTPS_PORT}"
export CONSUL_CACERT="${OUTPUT_FOLDER}secrets/consul-agent-ca.pem"
