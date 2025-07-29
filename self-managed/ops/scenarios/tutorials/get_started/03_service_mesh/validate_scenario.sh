#!/usr/bin/env bash

# ++-----------------+
# || Functions       |
# ++-----------------+

_check_value_in_range() {
	_value=$1
	_min_value=$2
	_max_value=$3

	if (( "${_min_value}" <= "${_max_value}")); then
		if (( "${_value}" >= "${_min_value}")); then
			if (( "${_value}" <= "${_max_value}")); then
				# Value in range
				echo 0
			else
				# Value too big
				echo 2
			fi
		else
			# Value too small
			echo 1
		fi
	else
		# Ranges are wrong MAX < MIN
		echo 3
	fi
}

# ++-----------------+
# || Variables       |
# ++-----------------+

export STEP_ASSETS="${SCENARIO_OUTPUT_FOLDER}conf/"

## [ux-diff] [cloud provider] UX differs across different Cloud providers
if [ "${SCENARIO_CLOUD_PROVIDER}" == "docker" ]; then
  export CONSUL_DNS_PORT="53"
elif [ "${SCENARIO_CLOUD_PROVIDER}" == "aws" ]; then
  export CONSUL_DNS_PORT="8600"
elif [ "${SCENARIO_CLOUD_PROVIDER}" == "azure" ]; then
  export CONSUL_DNS_PORT="8600"
else 
  log_err "Cloud provider $SCENARIO_CLOUD_PROVIDER is unsupported...exiting."
  exit 245
fi

# ++-----------------+
# || Begin           |
# ++-----------------+

header1 "Validate scenario Consul service mesh"

## Give scenario time to settle
sleep 6 

## Setup Environment variables
source ${SCENARIO_OUTPUT_FOLDER}/env-scenario.env
source ${SCENARIO_OUTPUT_FOLDER}/env-consul.env

# ==============================================================================
header2 "Check HashiCups configuration."
# ==============================================================================

HC_TITLE=`curl -sk https://gateway-api-0:8443 | grep -oPs "(?<=<title>).*(?=</title>)"`
# HC_TITLE=`curl -s http://hashicups-nginx-0 | grep -oPs "(?<=<title>).*(?=</title>)"`

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

SUBJ_CN=`echo | \
openssl s_client -showcerts \
-connect gateway-api-0:8443 2>/dev/null | \
openssl x509 -inform pem -noout -text | \
grep Subject: | awk '{print $NF}'`

OUTP=$?

if [ ! "${OUTP}" -eq "0" ] 
then
	log_err "HashiCups not responding."
	exit 3
elif [ ! "${SUBJ_CN}" == "hashicups.hashicorp.com" ] 
then 
	log_err "API Gateway certificate error."
	exit 4
fi

log "API Gateway presenting correct certificate."

# HC_API=`curl -s 'http://hashicups-api-0:8081/api' \
# 	-H 'Accept-Encoding: gzip, deflate, br' \
# 	-H 'Content-Type: application/json' \
# 	-H 'Accept: application/json' \
# 	-H 'Connection: keep-alive' \
# 	-H 'DNT: 1' \
# 	-H 'Origin: http://localhost:8081' \
# 	--data-binary '{"query":"mutation{ pay(details:{ name: \"nic\", type: \"mastercard\", number: \"1234123-0123123\", expiry:\"10/02\",    cv2: 1231, amount: 12.23 }){id, card_plaintext, card_ciphertext, message } }"}' --compressed | \
# 	jq -r .data.pay.id`

# OUTP=$?

# if [ ! "${OUTP}" -eq "0" ] 
# then
# 	log_err "HashiCups not responding."
# 	exit 3
# elif [ "${HC_API}test" == "test" ] 
# then 
# 	log_err "HashiCups backend error."
# 	exit 4
# fi

# log "HashiCups Backend correctly working."

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

# ==============================================================================
header2 "Check Consul client configuration."
# ==============================================================================

NODES_ARRAY=( "hashicups-db" "hashicups-api" "hashicups-frontend" "hashicups-nginx" )

for node in "${NODES_ARRAY[@]}"; do

  NUM="${node/-/_}""_NUMBER"
  
	CLI_NUM=`consul members | grep ${node} | grep alive | awk '{print $1}' | wc -l`

	OUTP=$?

	if [ ! "${OUTP}" -eq "0" ] 
	then
		log_err "Consum members not working."
		exit 8
	elif [ ! "${CLI_NUM}" -eq "${!NUM}" ] 
	then 
		log_err "Some Consul client nodes for ${node} are not started correctly."
		exit 9
	fi

	SVC_NUM=`dig +short \
		@consul-server-0 \
		-p ${CONSUL_DNS_PORT} \
		${node}.service.${CONSUL_DATACENTER}.${CONSUL_DOMAIN} | \
		wc -l`

	OUTP=$?

	if [ ! "${OUTP}" -eq "0" ] 
	then
		log_err "Consum DNS interface not working."
		exit 10
	elif [ ! "${SVC_NUM}" -eq "${!NUM}" ] 
	then 
		log_err "Some Consul services for ${node} are not registered correctly."
		exit 11
	fi

	log "All ${node} service instances correctly working."

    SIDECAR=`consul catalog services | grep ${node}-sidecar-proxy | wc -l`

    OUTP=$?

	if [ ! "${OUTP}" -eq "0" ] 
	then
		log_err "Consul catalog not working."
		exit 12
	elif [ ! "${SIDECAR}" -eq "1" ] 
	then 
		log_err "Sidecar proxy for ${node} are not starting correctly."
		exit 13
	fi

done

log_info "Test for scenario passed. Great job."
exit 0