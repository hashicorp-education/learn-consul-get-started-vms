#!/usr/bin/env bash

# ++-----------------+
# || Functions       |
# ++-----------------+

# _check_value_in_range() {
#     _value=$1
#     _min_value=$2
#     _max_value=$3

#     if (( "${_min_value}" <= "${_max_value}")); then
#         if (( "${_value}" >= "${_min_value}")); then
#             if (( "${_value}" <= "${_max_value}")); then
#                 # Value in range
#                 echo 0
#             else
#                 # Value too big
#                 echo 2
#             fi
#         else
#             # Value too small
#             echo 1
#         fi
#     else
#         # Ranges are wrong MAX < MIN
#         echo 3
#     fi
# }

# ++-----------------+
# || Variables       |
# ++-----------------+

export STEP_ASSETS="${SCENARIO_OUTPUT_FOLDER}conf/"

# ++-----------------+
# || Begin           |
# ++-----------------+

header1 "Validate scenario Deploy Consul on VMs"

## Setup Environment variables

export DATACENTER=${DATACENTER:-"dc1"}
export DOMAIN=${DOMAIN:-"consul"}
export CONSUL_DATA_DIR=${CONSUL_DATA_DIR:-"/opt/consul"}
export CONSUL_CONFIG_DIR=${CONSUL_CONFIG_DIR:-"/etc/consul.d"}

export CONSUL_HTTP_ADDR="https://consul-server-0:8443"
export CONSUL_HTTP_SSL=true
export CONSUL_CACERT="${STEP_ASSETS}secrets/consul-agent-ca.pem"
export CONSUL_TLS_SERVER_NAME="server.${DATACENTER}.${DOMAIN}"
export CONSUL_FQDN_ADDR="consul-server-0"

if [ -f ~/acl-token-bootstrap.json ]; then

  export CONSUL_HTTP_TOKEN=`cat ~/acl-token-bootstrap.json | jq -r ".SecretID"`

elif [ -f "${STEP_ASSETS}secrets/acl-token-bootstrap.json" ]; then

  export CONSUL_HTTP_TOKEN=`cat ${STEP_ASSETS}secrets/acl-token-bootstrap.json | jq -r ".SecretID"`

else
  log_err "Could not find bootstrap token file."
  exit 1
fi

# ==============================================================================
header2 "Check HashiCups configuration."
# ==============================================================================

HC_TITLE=`curl -s http://hashicups-nginx-0 | grep -oPs "(?<=<title>).*(?=</title>)"`

OUTP=$?

if [ ! "${OUTP}" -eq "0" ] 
then
	log_err "HashiCups not responding."
	exit 1
elif [ ! "${HC_TITLE}" == "HashiCups - Demo App" ] 
then 
	log_err "HashiCups frontend error."
	exit 2
fi

log "HashiCups Frontend correctly working."

HC_API=`curl -s 'http://hashicups-api-0:8081/api' \
	-H 'Accept-Encoding: gzip, deflate, br' \
	-H 'Content-Type: application/json' \
	-H 'Accept: application/json' \
	-H 'Connection: keep-alive' \
	-H 'DNT: 1' \
	-H 'Origin: http://localhost:8081' \
	--data-binary '{"query":"mutation{ pay(details:{ name: \"nic\", type: \"mastercard\", number: \"1234123-0123123\", expiry:\"10/02\",    cv2: 1231, amount: 12.23 }){id, card_plaintext, card_ciphertext, message } }"}' --compressed | \
	jq -r .data.pay.id`

OUTP=$?

if [ ! "${OUTP}" -eq "0" ] 
then
	log_err "HashiCups not responding."
	exit 3
elif [ "${HC_API}test" == "test" ] 
then 
	log_err "HashiCups backend error."
	exit 4
fi

log "HashiCups Backend correctly working."

# ==============================================================================
header2 "Check Consul server configuration."
# ==============================================================================

consul info > /dev/null

OUTP=$?

if [ ! "${OUTP}" -eq "0" ]

then
	# Consul info is not responding
	# Either Consul is down or ACL is not bootstrapped
	log_err "Consul info is not responding. Consul server might be down."
	exit 5
fi

log "Consul datacenter correctly working."

SER_NUM=`consul members | grep consul-server | grep alive | awk '{print $1}' | wc -l`

OUTP=$?

if [ ! "${OUTP}" -eq "0" ] 
then
	log_err "Consum members not working."
	exit 6
elif [ ! "${SER_NUM}" -eq "${CONSUL_SERVER_NUMBER}" ] 
then 
	log_err "Some Consul server nodes are not started correctly."
	exit 7
fi

log "All Consul servers correctly working."
