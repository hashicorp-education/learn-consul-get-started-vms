#!/usr/bin/env bash

WORKDIR="/home/app/"
ASSETS="${WORKDIR}assets/"
# LOGS="${WORKDIR}logs/"

mkdir -p ${ASSETS}

export DATACENTER=${DATACENTER:-"dc1"}
export DOMAIN=${DOMAIN:-"consul"}
export CONSUL_DATA_DIR=${CONSUL_DATA_DIR:-"/etc/consul/data"}
export CONSUL_CONFIG_DIR=${CONSUL_CONFIG_DIR:-"/etc/consul/config"}

export CONSUL_HTTP_ADDR="https://consul${FQDN_SUFFIX}:8443"
export CONSUL_HTTP_SSL=true
export CONSUL_CACERT="${CONSUL_CONFIG_DIR}/consul-agent-ca.pem"
export CONSUL_TLS_SERVER_NAME="server.${DATACENTER}.${DOMAIN}"
export CONSUL_FQDN_ADDR="consul${FQDN_SUFFIX}"

export CONSUL_HTTP_TOKEN=`cat ./acl-token-bootstrap.json | jq -r ".SecretID"`

echo "Create ACL policies and tokens"

tee ${ASSETS}acl-policy-dns.hcl > /dev/null << EOF
## dns-request-policy.hcl
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
EOF

tee ${ASSETS}acl-policy-server-node.hcl > /dev/null << EOF
## consul-server-one-policy.hcl
node_prefix "consul" {
  policy = "write"
}
EOF

consul acl policy create -name 'acl-policy-dns' -description 'Policy for DNS endpoints' -rules @${ASSETS}acl-policy-dns.hcl  > /dev/null 2>&1

consul acl policy create -name 'acl-policy-server-node' -description 'Policy for Server nodes' -rules @${ASSETS}acl-policy-server-node.hcl  > /dev/null 2>&1

consul acl token create -description 'DNS - Default token' -policy-name acl-policy-dns --format json > ${ASSETS}acl-token-dns.json 2> /dev/null

DNS_TOK=`cat ${ASSETS}acl-token-dns.json | jq -r ".SecretID"` 

## Create one agent token per server
echo "Setup ACL tokens for Server"

consul acl token create -description "server agent token" -policy-name acl-policy-server-node  --format json > ${ASSETS}server-acl-token.json 2> /dev/null

SERV_TOK=`cat ${ASSETS}server-acl-token.json | jq -r ".SecretID"`

consul acl set-agent-token agent ${SERV_TOK}
consul acl set-agent-token default ${DNS_TOK}