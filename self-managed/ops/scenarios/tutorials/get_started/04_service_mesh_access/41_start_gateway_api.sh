#!/usr/bin/env bash

# ++-----------------+
# || Variables       |
# ++-----------------+

export STEP_ASSETS="${SCENARIO_OUTPUT_FOLDER}conf/"

CERT_TYPE=inline

# ++-----------------+
# || Begin           |
# ++-----------------+

header1 "Configure and start Consul API gateway nodes"

if [ "${api_gw_NUMBER}" == 0 ]; then
  log "No API Gateway node configured. Skipping."
fi

################################################################################
header2 "Start Consul agent on API gateway nodes"

for i in `seq ${api_gw_NUMBER}`; do

  NODE_NAME="gateway-api-$((i-1))"

  log "Starting Consul agent for ${NODE_NAME}"

  mkdir -p "${STEP_ASSETS}${NODE_NAME}"

  log_debug "Copy available configuration"

  cp -r ${STEP_ASSETS}secrets/*.hcl "${STEP_ASSETS}${NODE_NAME}/"
  cp "${STEP_ASSETS}secrets/consul-agent-ca.pem" "${STEP_ASSETS}${NODE_NAME}/"

  log_debug "Generating configuration for Consul agent "

  tee ${STEP_ASSETS}${NODE_NAME}/consul.hcl > /dev/null << EOF
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
recursors = ["1.1.1.1"]

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

# Enable central service config
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
  # default_policy = "allow"
  default_policy = "deny"
  enable_token_persistence = true
}
EOF

  log_debug "Generate ACL tokens"
  
  ## todo currently using bootstrap token, generate specific tokens in future refactors
  AGENT_TOKEN=${CONSUL_HTTP_TOKEN}
  DNS_TOK=`cat ${STEP_ASSETS}secrets/acl-token-dns.json | jq -r ".SecretID"` 

  tee ${STEP_ASSETS}${NODE_NAME}/agent-acl-tokens.hcl > /dev/null << EOF
acl {
  tokens {
    agent  = "${AGENT_TOKEN}"
    default  = "${DNS_TOK}"
    config_file_service_registration = "${AGENT_TOKEN}"
  }
}
EOF

  log "Start Consul"

  log_debug "Clean remote node"
  remote_exec -o ${NODE_NAME} "sudo rm -rf ${CONSUL_CONFIG_DIR}* && \
                            sudo rm -rf ${CONSUL_DATA_DIR}* && \
                            sudo chmod g+w ${CONSUL_DATA_DIR}"

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

  log_debug "Copy configuration on client nodes"
  remote_copy ${NODE_NAME} "${STEP_ASSETS}${NODE_NAME}/*" "${CONSUL_CONFIG_DIR}"

  log_debug "Start Consul agent"

  remote_exec ${NODE_NAME} \
      "/usr/bin/consul agent \
      -log-file=/tmp/consul-client \
      -config-dir=${CONSUL_CONFIG_DIR} > /tmp/consul-client.log 2>&1 &" 

done

################################################################################
header2 "Configure and start API gateway"

if [ "${ENABLE_SERVICE_MESH}" == "true" ]; then

  if [ "${api_gw_NUMBER}" -gt "0" ]; then
    
    header3 "Generate TLS certificate for HashiCups"

    pushd ${STEP_ASSETS}secrets

    # https://www.golinuxcloud.com/shell-script-to-generate-certificate-openssl/
    COMMON_NAME="hashicups.hashicorp.com"

    log "Generate certificate with CN=${COMMON_NAME}"

    log_debug "Generate openssl config"
    # Generate openssl config
    tee ./gateway-api-ca-config.cnf > /dev/null << EOT
[req]
default_bit = 4096
distinguished_name = req_distinguished_name
prompt = no

[req_distinguished_name]
countryName             = US
stateOrProvinceName     = California
localityName            = San Francisco
organizationName        = HashiCorp
commonName              = ${COMMON_NAME}
EOT

    log_debug "Generate private key"
    openssl genrsa -out gateway-api-cert.key  4096 2>/dev/null

    log_debug "Generate CSR"
    openssl req -new -key gateway-api-cert.key -out gateway-api-cert.csr -config gateway-api-ca-config.cnf 2>/dev/null

    log_debug "Generate certificate"
    openssl x509 -req -days 3650 -in gateway-api-cert.csr -signkey gateway-api-cert.key -out gateway-api-cert.crt 2>/dev/null

    API_GW_KEY=`cat gateway-api-cert.key`
    API_GW_CERT=`cat gateway-api-cert.crt`

    popd

    tee ${STEP_ASSETS}config-gateway-api-certificate.hcl > /dev/null << EOT
Kind = "inline-certificate"
Name = "api-gw-certificate"

Certificate = <<EOF
${API_GW_CERT}
EOF

PrivateKey = <<EOF
${API_GW_KEY}
EOF
EOT

    consul config write ${STEP_ASSETS}config-gateway-api-certificate.hcl

    header3 "Generate API Gateway rules"

    ## todo Configuring only the first instance. Make it a cycle.
    NODE_NAME="gateway-api-0"

    PORT_NUM=8443

    tee ${STEP_ASSETS}config-gateway-api.hcl > /dev/null << EOF
Kind = "api-gateway"
Name = "gateway-api"

// Each listener configures a port which can be used to access the Consul cluster
Listeners = [
    {
        Port = ${PORT_NUM}
        Name = "api-gw-listener"
        Protocol = "http"
        TLS = {
            Certificates = [
                {
                    Kind = "inline-certificate"
                    Name = "api-gw-certificate"
                }
            ]
        }
    }
]
EOF

    consul config write ${STEP_ASSETS}config-gateway-api.hcl

    sleep 2

    tee ${STEP_ASSETS}config-gateway-api-http-route.hcl > /dev/null << EOF
Kind = "http-route"
Name = "hashicups-http-route"

Rules = [
  {
    Matches = [
      {
        Path = {
          Match = "prefix"
          Value = "/"
        }
      }
    ]
    Services = [
      {
        Name = "hashicups-nginx"
        Weight = 100
      }
    ]
  }
]

Parents = [
  {
    Kind = "api-gateway"
    Name = "gateway-api"
    SectionName = "api-gw-listener"
  }
]
EOF

    consul config write ${STEP_ASSETS}config-gateway-api-http-route.hcl

    header3 "Create intention for API gateway"

    tee ${STEP_ASSETS}global/intention-nginx.hcl > /dev/null << EOF
      Kind = "service-intentions"
      Name = "hashicups-nginx"
      Sources = [
        {
          Name   = "gateway-api"
          Action = "allow"
        }
      ]
EOF

    consul config write ${STEP_ASSETS}global/intention-nginx.hcl

    sleep 2

    header3 "Start Envoy sidecar for API GW"

    AGENT_TOKEN=${CONSUL_HTTP_TOKEN}

    for i in `seq ${api_gw_NUMBER}`; do

      NODE_NAME="gateway-api-$((i-1))"

      log "Starting Envoy for ${NODE_NAME}"

      remote_exec -o ${NODE_NAME} "/usr/bin/consul connect envoy \
                            -gateway api \
                            -register \
                            -service gateway-api \
                            -token=${AGENT_TOKEN} \
                            -envoy-binary /usr/bin/envoy \
                            ${ENVOY_EXTRA_OPT} -- -l ${ENVOY_LOG_LEVEL} > /tmp/api-gw-proxy.log 2>&1 &"
    done

  else

    log_warn "Consul service mesh is enabled but no API Gateway is deployed."  
  
  fi

else

  log_warn "Consul service mesh is not configured. Skipping API Gateway configuration."

fi

header2 "Restart hashicups-nginx to listen locally"

NODES_ARRAY=( "hashicups-nginx" )

for node in "${NODES_ARRAY[@]}"; do

  NUM="${node/-/_}""_NUMBER"
  
  for i in `seq ${!NUM}`; do

    export NODE_NAME="${node}-$((i-1))"      
    
    log "Restart service on ${NODE_NAME}" 

    remote_exec ${NODE_NAME} "~/start_service.sh start --local"

  done
done