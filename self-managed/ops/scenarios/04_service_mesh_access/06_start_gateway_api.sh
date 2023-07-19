#!/usr/bin/env bash

# ++-----------------+
# || Variables       |
# ++-----------------+

export STEP_ASSETS="${ASSETS}scenario/conf/"

export NODES_ARRAY=( "hashicups-db" "hashicups-api" "hashicups-frontend" "hashicups-nginx" )

CONSUL_LOG_LEVEL="DEBUG"

# ++-----------------+
# || Begin           |
# ++-----------------+

header1 "Starting Consul API gateway"

header2 "Generate Consul configuration"

NODE_NAME="gateway-api"

mkdir -p "${STEP_ASSETS}${NODE_NAME}"

log "Copy available configuration"

cp -r ${STEP_ASSETS}secrets/*.hcl "${STEP_ASSETS}${NODE_NAME}/"
cp "${STEP_ASSETS}secrets/consul-agent-ca.pem" "${STEP_ASSETS}${NODE_NAME}/"

log "Generating configuration for Consul agent "

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
bind_addr   = "{{ GetInterfaceIP \"eth0\" }}"

# Join other Consul agents
retry_join = [ "${CONSUL_RETRY_JOIN}" ]

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

# ## TLS Encryption
# tls {
#   defaults {
#     ca_file   = "/etc/consul.d/consul-agent-ca.pem"
#     verify_outgoing        = true
#     verify_incoming        = true
#   }
#   https {
#     verify_incoming        = false
#   }
#   internal_rpc {
#     verify_server_hostname = true
#   }
#   grpc {
#     verify_incoming        = false
#     use_auto_cert = true
#   }
# }

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
  # grpc {
  #   verify_incoming        = false
  #   verify_outgoing        = true
  #   use_auto_cert          = false
  # }
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

header2 "Generate ACL tokens"

AGENT_TOKEN=${CONSUL_HTTP_TOKEN}
DNS_TOK=${CONSUL_HTTP_TOKEN}

tee ${STEP_ASSETS}${NODE_NAME}/agent-acl-tokens.hcl > /dev/null << EOF
acl {
  tokens {
    agent  = "${AGENT_TOKEN}"
    default  = "${DNS_TOK}"
    config_file_service_registration = "${AGENT_TOKEN}"
  }
}
EOF

header2 "Start Consul"

log "Clean remote node"
remote_exec ${NODE_NAME} "sudo rm -rf ${CONSUL_CONFIG_DIR}* && \
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

log "Copy configuration on client nodes"
remote_copy ${NODE_NAME} "${STEP_ASSETS}${NODE_NAME}/*" "${CONSUL_CONFIG_DIR}"

log "Start Consul agent"

remote_exec ${NODE_NAME} \
    "/usr/bin/consul agent \
    -log-file=/tmp/consul-client \
    -config-dir=${CONSUL_CONFIG_DIR} > /tmp/consul-client.log 2>&1 &" 


sleep 2

header2 "Generate API Gateway rules"



tee ${STEP_ASSETS}config-gateway-api.hcl > /dev/null << EOF
Kind = "api-gateway"
Name = "gateway-api"

// Each listener configures a port which can be used to access the Consul cluster
Listeners = [
    {
        Port = 8443
        Name = "api-gw-listener"
        # Protocol = "http"
        Protocol = "tcp"
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

log "Generate API gateway certificate"

pushd ${STEP_ASSETS}secrets

# https://www.golinuxcloud.com/shell-script-to-generate-certificate-openssl/
COMMON_NAME="hashicups.hashicorp.com"

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

openssl genrsa -out gateway-api-cert.key  4096 2>/dev/null
openssl req -new -key gateway-api-cert.key -out gateway-api-cert.csr -config gateway-api-ca-config.cnf 2>/dev/null
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

tee ${STEP_ASSETS}config-gateway-api-tcp-route.hcl > /dev/null << EOF
Kind = "tcp-route"
Name = "hashicups-tcp-route"

Services = [
  {
    Name = "hashicups-nginx"
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


header2 "Start Envoy sidecar for API GW"

consul config write ${STEP_ASSETS}config-gateway-api.hcl
consul config write ${STEP_ASSETS}config-gateway-api-certificate.hcl

log "Start new instance"
remote_exec ${NODE_NAME} "/usr/bin/consul connect envoy \
                            -gateway api \
                            -register \
                            -service gateway-api \
                            -token=${AGENT_TOKEN} \
                            -envoy-binary /usr/bin/envoy \
                            ${ENVOY_EXTRA_OPT} -- -l trace > /tmp/api-gw-proxy.log 2>&1 &"


consul config write ${STEP_ASSETS}config-gateway-api-tcp-route.hcl

