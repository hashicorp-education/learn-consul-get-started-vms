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

CONSUL_DATACENTER=${CONSUL_DATACENTER:-"dc1"}
CONSUL_DOMAIN=${CONSUL_DOMAIN:-"consul"}
CONSUL_CONFIG_DIR=${CONSUL_CONFIG_DIR:-"/etc/consul.d/"}
CONSUL_DATA_DIR=${CONSUL_DATA_DIR:-"/opt/consul/"}
CONSUL_LOG_LEVEL=${CONSUL_LOG_LEVEL:-"DEBUG"}

CONSUL_DNS_RECURSOR=${CONSUL_DNS_RECURSOR:-"1.1.1.1"}

OUTPUT_FOLDER=${OUTPUT_FOLDER:-"${STEP_ASSETS}"}

# ++-----------------+
# || Begin           |
# ++-----------------+
_header "- Generate configuration for [${NODE_NAME}]"

_log "+ --------------------"
_log "| Parameter Check"
_log "+ --------------------"
_log_warn "Script is running with the following values:"
_log_warn "----------"
_log_warn "CONSUL_DATACENTER = ${CONSUL_DATACENTER}"
_log_warn "CONSUL_DOMAIN = ${CONSUL_DOMAIN}"
_log_warn "CONSUL_RETRY_JOIN = ${CONSUL_RETRY_JOIN}"

_log_warn "CONSUL_CONFIG_DIR = ${CONSUL_CONFIG_DIR:-"/etc/consul.d/"}"
_log_warn "CONSUL_DATA_DIR = ${CONSUL_DATA_DIR:-"/opt/consul/"}"
_log_warn "----------"

_log_warn "Generated configuration will be placed under:"
_log_warn "OUTPUT_FOLDER = ${OUTPUT_FOLDER:-"${STEP_ASSETS}"}"
_log_warn "----------"

[ -z "$OUTPUT_FOLDER" ]     && _log_err "Mandatory parameter: OUTPUT_FOLDER not set."      && exit 1
[ -z "$NODE_NAME" ]         && _log_err "Mandatory parameter: NODE_NAME not set."          && exit 1
[ -z "$CONSUL_RETRY_JOIN" ] && _log_err "Mandatory parameter: CONSUL_RETRY_JOIN not set."  && exit 1

_log ""
_log "+ --------------------"
_log "| Generate configuration for Consul agent ${NODE_NAME}"
_log "+ --------------------"

_log " - Cleaning folder from pre-existing files"
_log_warn "Removing pre-existing configuration in ${OUTPUT_FOLDER}"
rm -rf "${OUTPUT_FOLDER}${NODE_NAME}"

_log " - Generate folder structure"

mkdir -p "${OUTPUT_FOLDER}${NODE_NAME}"

_log " - Copy available configuration"

cp -r ${OUTPUT_FOLDER}secrets/*.hcl "${OUTPUT_FOLDER}${NODE_NAME}/"
cp "${OUTPUT_FOLDER}secrets/consul-agent-ca.pem" "${OUTPUT_FOLDER}${NODE_NAME}/"

_log " - Generate configuration files"

tee ${OUTPUT_FOLDER}${NODE_NAME}/consul.hcl > /dev/null << EOF
# -----------------------------+
# consul.hcl                   |
# -----------------------------+

server = false
datacenter = "${CONSUL_DATACENTER}"
domain = "${CONSUL_DOMAIN}" 
node_name = "${NODE_NAME}"

# Logging
log_level = "${CONSUL_LOG_LEVEL}"
enable_syslog = false

# Data persistence
data_dir = "${CONSUL_DATA_DIR}"

## Networking 
client_addr = "127.0.0.1"
bind_addr   = "{{ GetInterfaceIP \"eth0\" }} {{ GetInterfaceIP \"enX0\" }}"

# Join other Consul agents
retry_join = [ "${CONSUL_RETRY_JOIN}", "consul.service.${CONSUL_DATACENTER}.${CONSUL_DOMAIN}" ]

# DNS recursors
recursors = ["${CONSUL_DNS_RECURSOR}"]

# Ports
ports {
  http      = 8500
  https     = -1
  # https   = 443
  grpc      = 8502
  # grpc_tls  = 8503
  grpc_tls  = -1
  dns       = 8600
}

# Enable Consul service mesh
connect {
  enabled = true
}

## Disable script checks
enable_script_checks = false

## Enable local script checks
enable_local_script_checks = true

## Enable central service config
enable_central_service_config = true

## Automatically reload reloadable configuration
auto_reload_config = true

## TLS Encryption
tls {
  # defaults { }
  https {
    ca_file   = "${CONSUL_CONFIG_DIR}consul-agent-ca.pem"
    verify_incoming        = false
    verify_outgoing        = true
  }
  internal_rpc {
    ca_file   = "${CONSUL_CONFIG_DIR}consul-agent-ca.pem"
    verify_incoming        = true
    verify_outgoing        = true
    verify_server_hostname = true
  }
}

auto_encrypt {
  tls = true
}

## ACL
acl {
  enabled        = true
  default_policy = "deny"
  enable_token_persistence = true
}
EOF

_log " - Validate configuration for ${NODE_NAME}"
consul validate ${OUTPUT_FOLDER}${NODE_NAME}  > /dev/null 2>&1

STAT=$?

if [ ${STAT} -ne 0 ];  then
  _log_err "Configuration invalid. Exiting."
  exit 1;
fi

exit 0


