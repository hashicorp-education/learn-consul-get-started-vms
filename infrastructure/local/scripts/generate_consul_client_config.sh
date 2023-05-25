#!/usr/bin/env bash

export DATACENTER=${DATACENTER:-"dc1"}
export DOMAIN=${DOMAIN:-"consul"}
export CONSUL_DATA_DIR=${CONSUL_DATA_DIR:-"/etc/consul/data"}
export CONSUL_CONFIG_DIR=${CONSUL_CONFIG_DIR:-"/etc/consul/config"}

export DNS_RECURSOR=${DNS_RECURSOR:-"1.1.1.1"}
export HTTPS_PORT=${HTTPS_PORT:-"8443"}
export DNS_PORT=${DNS_PORT:-"8600"}

export SERVER_NAME=${SERVER_NAME:-"consul"}
export FQDN_SUFFIX=${FQDN_SUFFIX:-""}
export CA_CERT=${CA_CERT:-"/home/app/assets/consul-agent-ca.pem"}
export GOSSIP_CONFIG=${GOSSIP_CONFIG:-"/home/app/assets/agent-gossip-encryption.hcl"}

CONFIGS="./client_configs"

rm -rf ${CONFIGS}

mkdir -p ${CONFIGS}
mkdir -p ${CONFIGS}/db ${CONFIGS}/api ${CONFIGS}/frontend ${CONFIGS}/nginx

echo "Generate Consul agent configuration"

tee ${CONFIGS}/agent-client-secure.hcl > /dev/null << EOF
## agent-client-secure.hcl
server = false
datacenter = "${DATACENTER}"
domain = "${DOMAIN}" 

# Logging
log_level = "DEBUG"

#client_addr = "127.0.0.1"

retry_join = [ "${SERVER_NAME}${FQDN_SUFFIX}" ]

# Ports

ports {
  grpc  = 8502
  http  = 8500
  https = 8443
  dns   = 8600
}

enable_script_checks = false

enable_central_service_config = true

data_dir = "/etc/consul/data"

## TLS Encryption (requires cert files to be present on the server nodes)
# tls {
#   defaults {
#     ca_file   = "/etc/consul/config/consul-agent-ca.pem"
#     verify_outgoing        = true
#     verify_incoming        = true
#   }
#   https {
#     verify_incoming        = false
#   }
#   internal_rpc {
#     verify_server_hostname = true
#   }
# }

## TLS Encryption (requires cert files to be present on the server nodes)
ca_file   = "/etc/consul/config/consul-agent-ca.pem"
verify_incoming        = false
verify_incoming_rpc    = true
verify_outgoing        = true
verify_server_hostname = true

auto_encrypt {
  tls = true
}

acl {
  enabled        = true
  default_policy = "deny"
  enable_token_persistence = true
}
EOF

##################
## Database
##################
SERVICE="db"
NODE_NAME=${SERVICE}

echo "Create node ${SERVICE} specific configuration"

cp ${CONFIGS}/agent-client-secure.hcl ${CONFIGS}/${SERVICE}/agent-client-secure.hcl
cp ${GOSSIP_CONFIG} ${CONFIGS}/${SERVICE}/
cp ${CA_CERT} ${CONFIGS}/${SERVICE}/

# consul acl token create -description "svc-${dc}-${svc} agent token" -node-identity "${ADDR}:${dc}" -service-identity="${svc}"  --format json > ${ASSETS}/acl-token-${ADDR}.json 2> /dev/null
# AGENT_TOK=`cat ${ASSETS}/acl-token-${ADDR}.json | jq -r ".SecretID"`

# Using root token for now
AGENT_TOKEN=`cat /home/app/assets/acl-token-bootstrap.json | jq -r ".SecretID"`

tee ${CONFIGS}/${SERVICE}/agent-client-acl-tokens.hcl > /dev/null << EOF
acl {
  tokens {
    agent  = "${AGENT_TOKEN}"
    default  = "${AGENT_TOKEN}"
  }
}
EOF

echo "Create service ${SERVICE} configuration"

tee ${CONFIGS}/${SERVICE}/svc-${SERVICE}.hcl > /dev/null << EOF
## svc-${SERVICE}.hcl
service {
  name = "${SERVICE}"
  id = "${SERVICE}-1"
  tags = ["v1"]
  port = 5432
  
  check {
    id =  "check-${SERVICE}",
    name = "Product ${SERVICE} status check",
    service_id = "${SERVICE}-1",
    tcp  = "localhost:5432",
    interval = "1s",
    timeout = "1s"
  }
}
EOF


##################
## API
##################

SERVICE="api"
NODE_NAME=${SERVICE}

echo "Create node ${SERVICE} specific configuration"

cp ${CONFIGS}/agent-client-secure.hcl ${CONFIGS}/${SERVICE}/agent-client-secure.hcl
cp ${GOSSIP_CONFIG} ${CONFIGS}/${SERVICE}/
cp ${CA_CERT} ${CONFIGS}/${SERVICE}/

# consul acl token create -description "svc-${dc}-${svc} agent token" -node-identity "${ADDR}:${dc}" -service-identity="${svc}"  --format json > ${ASSETS}/acl-token-${ADDR}.json 2> /dev/null
# AGENT_TOK=`cat ${ASSETS}/acl-token-${ADDR}.json | jq -r ".SecretID"`

# Using root token for now
AGENT_TOKEN=`cat /home/app/assets/acl-token-bootstrap.json | jq -r ".SecretID"`

tee ${CONFIGS}/${SERVICE}/agent-client-acl-tokens.hcl > /dev/null << EOF
acl {
  tokens {
    agent  = "${AGENT_TOKEN}"
    default  = "${AGENT_TOKEN}"
  }
}
EOF

echo "Create service ${SERVICE} configuration"

tee ${CONFIGS}/${SERVICE}/svc-${SERVICE}.hcl > /dev/null << EOF
## svc-${SERVICE}.hcl
service {
  name = "${SERVICE}"
  id = "${SERVICE}-1"
  tags = ["v1"]
  port = 8080
  
  checks =[ 
    {
      id =  "check-public-api",
      name = "Public API status check",
      service_id = "${SERVICE}-1",
      tcp  = "hashicups-${SERVICE}${FQDN_SUFFIX}:8081",
      interval = "1s",
      timeout = "1s"
    },
    {
      id =  "check-payments",
      name = "Payments status check",
      service_id = "${SERVICE}-1",
      tcp  = "hashicups-${SERVICE}${FQDN_SUFFIX}:8080",
      interval = "1s",
      timeout = "1s"
    },
    {
      id =  "check-product-api",
      name = "Product API status check",
      service_id = "${SERVICE}-1",
      tcp  = "hashicups-${SERVICE}${FQDN_SUFFIX}:9090",
      interval = "1s",
      timeout = "1s"
    }
  ]
}
EOF

##################
## Frontend
##################
SERVICE="frontend"
NODE_NAME=${SERVICE}

echo "Create node ${SERVICE} specific configuration"

cp ${CONFIGS}/agent-client-secure.hcl ${CONFIGS}/${SERVICE}/agent-client-secure.hcl
cp ${GOSSIP_CONFIG} ${CONFIGS}/${SERVICE}/
cp ${CA_CERT} ${CONFIGS}/${SERVICE}/

# consul acl token create -description "svc-${dc}-${svc} agent token" -node-identity "${ADDR}:${dc}" -service-identity="${svc}"  --format json > ${ASSETS}/acl-token-${ADDR}.json 2> /dev/null
# AGENT_TOK=`cat ${ASSETS}/acl-token-${ADDR}.json | jq -r ".SecretID"`

# Using root token for now
AGENT_TOKEN=`cat /home/app/assets/acl-token-bootstrap.json | jq -r ".SecretID"`

tee ${CONFIGS}/${SERVICE}/agent-client-acl-tokens.hcl > /dev/null << EOF
acl {
  tokens {
    agent  = "${AGENT_TOKEN}"
    default  = "${AGENT_TOKEN}"
  }
}
EOF

echo "Create service ${SERVICE} configuration"

tee ${CONFIGS}/${SERVICE}/svc-${SERVICE}.hcl > /dev/null << EOF
## svc-${SERVICE}.hcl
service {
  name = "${SERVICE}"
  id = "${SERVICE}-1"
  tags = ["v1"]
  port = 3000
  
  check {
    id =  "check-${SERVICE}",
    name = "Product ${SERVICE} status check",
    service_id = "${SERVICE}-1",
    tcp  = "hashicups-${SERVICE}${FQDN_SUFFIX}:3000",
    interval = "1s",
    timeout = "1s"
  }
}
EOF

##################
## NGINX
##################

SERVICE="nginx"
NODE_NAME=${SERVICE}

echo "Create node ${SERVICE} specific configuration"

cp ${CONFIGS}/agent-client-secure.hcl ${CONFIGS}/${SERVICE}/agent-client-secure.hcl
cp ${GOSSIP_CONFIG} ${CONFIGS}/${SERVICE}/
cp ${CA_CERT} ${CONFIGS}/${SERVICE}/

# consul acl token create -description "svc-${dc}-${svc} agent token" -node-identity "${ADDR}:${dc}" -service-identity="${svc}"  --format json > ${ASSETS}/acl-token-${ADDR}.json 2> /dev/null
# AGENT_TOK=`cat ${ASSETS}/acl-token-${ADDR}.json | jq -r ".SecretID"`

# Using root token for now
AGENT_TOKEN=`cat /home/app/assets/acl-token-bootstrap.json | jq -r ".SecretID"`

tee ${CONFIGS}/${SERVICE}/agent-client-acl-tokens.hcl > /dev/null << EOF
acl {
  tokens {
    agent  = "${AGENT_TOKEN}"
    default  = "${AGENT_TOKEN}"
  }
}
EOF

echo "Create service ${SERVICE} configuration"

tee ${CONFIGS}/${SERVICE}/svc-${SERVICE}.hcl > /dev/null << EOF
## svc-${SERVICE}.hcl
service {
  name = "${SERVICE}"
  id = "${SERVICE}-1"
  tags = ["v1"]
  port = 80
  
  check {
    id =  "check-${SERVICE}",
    name = "Product ${SERVICE} status check",
    service_id = "${SERVICE}-1",
    tcp  = "hashicups-${SERVICE}${FQDN_SUFFIX}:80",
    interval = "1s",
    timeout = "1s"
  }
}
EOF