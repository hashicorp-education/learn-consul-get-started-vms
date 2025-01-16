#!/usr/bin/env bash

# ++-----------------+
# || Functions       |
# ++-----------------+

# ++-----------------+
# || Variables       |
# ++-----------------+

username=${username:-$(whoami)}

export STEP_ASSETS="${SCENARIO_OUTPUT_FOLDER}conf/"


SCENARIO_NAME="GS_03_service_mesh"
export MD_RUNBOOK_FILE="/home/${username}/runbooks/self_managed-${SCENARIO_CLOUD_PROVIDER}-${SCENARIO_NAME}-runbook.md"

## Remove previous runbook files if any
rm -rf ${MD_RUNBOOK_FILE}

## Make sure folder exists
mkdir -p "/home/${username}/runbooks"

sudo chown ${USERNAME} /home/${username}/runbooks

# ++-----------------+
# || Begin           |
# ++-----------------+

# H1 ===========================================================================
md_h1 "Securely connect your services with Consul service mesh"
# ==============================================================================

md_log "This is a solution runbook for the scenario deployed."

##  H2 -------------------------------------------------------------------------
md_h2 "Prerequisites"
# ------------------------------------------------------------------------------

### H3 .........................................................................
md_h3 "Login into the bastion host VM" 
# ..............................................................................  

md_log "Login to the bastion host using ssh"

## [ux-diff] [cloud provider] UX differs across different Cloud providers 
if [ "${SCENARIO_CLOUD_PROVIDER}" == "docker" ]; then

  md_log_cmd -s shell-session 'ssh -i images/base/certs/id_rsa '${username}'@localhost -p 2222`
#...
'${username}'@bastion:~$'

elif [ "${SCENARIO_CLOUD_PROVIDER}" == "aws" ]; then
  
  md_log_cmd -s shell-session  'ssh -i certs/id_rsa.pem '${username}'@`terraform output -raw ip_bastion`
#...
'${username}'@bastion:~$'

elif [ "${SCENARIO_CLOUD_PROVIDER}" == "azure" ]; then
  
  md_log_cmd -s shell-session 'ssh -i certs/id_rsa.pem '${username}'@`terraform output -raw ip_bastion`
#...
'${username}'@bastion:~$'

else

  log_err "Cloud provider $SCENARIO_CLOUD_PROVIDER is unsupported...exiting."

  exit 245
fi

### H3 .........................................................................
md_h3 "Verify Envoy binary" 
# ..............................................................................  

md_log 'Check on each of the client nodes to verify Envoy is installed.
1. **NGINX**: `hashicups-nginx-0`
1. **Frontend**: `hashicups-frontend-0`
1. **API**: `hashicups-api-0`
1. **Database**: `hashicups-db-0`'

md_log 'For example, to check Envoy installation on the Database VM.'

_CONNECT_TO 'hashicups-db-0'

md_log 'Verify Envoy binary is installed.'

_RUN_CMD -r hashicups-db-0 -c 'envoy --version'

md_log "Check if the Envoy version is compatible with the Consul version running 
using the related [compatibility matrix](/consul/docs/connect/proxies/envoy#envoy-and-consul-client-agent)."

_EXIT_FROM 'hashicups-db-0'

md_log 'Repeat the steps for all VMs you want to add to the Consul service mesh.'

##  H2 -------------------------------------------------------------------------
md_h2 "Configure environment"
# ------------------------------------------------------------------------------

md_log "The lab contains two environment files that will help you configure the 
terminal and generate the required configuration files."

_RUN_CMD -c 'ls -1 ~/assets/scenario/env*.env'

md_log "Import the two files in your environment."

_RUN_CMD -h 'source ~/assets/scenario/env-scenario.env; \
source ~/assets/scenario/env-consul.env'

source ~/assets/scenario/env-scenario.env
source ~/assets/scenario/env-consul.env

md_log "The script creates all the files in a destination folder. 
Export the path where you wish to create the configuration files for the scenario."

# set -x

_RUN_CMD -h "export OUTPUT_FOLDER=${STEP_ASSETS}"
export OUTPUT_FOLDER="${STEP_ASSETS}"

md_log "Make sure the folder exists."

_RUN_CMD -h 'mkdir -p ${OUTPUT_FOLDER}' 

md_log "Verify your Consul CLI can interact with your Consul server."

_RUN_CMD -c 'consul members'

##  H2 -------------------------------------------------------------------------
md_h2 "Review and create intentions"
# ------------------------------------------------------------------------------

md_log "The initial Consul configuration denies all service connections by 
default. We recommend this setting in production environments to follow the 
"least-privilege" principle, by restricting all network access unless explicitly defined."

md_log "[Intentions](/consul/docs/connect/intentions) let you allow and restrict 
access between services. Intentions are *destination-orientated* — this means you 
create the intentions for the destination, then define which services can access it."

md_log 'The following intentions are required for HashiCups:
1. The `db` service needs to be reached by the `api` service.
1. The `api` service needs to be reached by the `nginx` services.
1. The `frontend` service needs to be reached by the `nginx` service.'

md_log 'Use the provided script to generate service intentions.'

export COLORED_OUTPUT=false
export PREPEND_DATE=false

## [cmd] [script] generate_global_config_hashicups.sh
_RUN_CMD -c "~/ops/scenarios/00_base_scenario_files/supporting_scripts/generate_global_config_hashicups.sh"

md_log 'Check the files generated by the script.'

_RUN_CMD -c 'tree ${OUTPUT_FOLDER}/global'

md_log 'Finally apply the intentions to your Consul datacenter.'

#### TAB ._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._
md_log "#### CLI == transform to TAB == " 
# ._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._

# ### H3 .........................................................................
# md_h3 "CLI == transform to TAB == " 
# # ..............................................................................

md_log 'Use `consul config write` to apply the intentions.'

md_log 'Create the intentions for the `hashicups-db` service.'

_RUN_CMD -c 'consul config write ${OUTPUT_FOLDER}global/intention-db.hcl'

md_log 'Create the intentions for the `hashicups-api` service.'

_RUN_CMD -c 'consul config write ${OUTPUT_FOLDER}global/intention-api.hcl'

md_log 'Create the intentions for the `hashicups-frontend` service.'

_RUN_CMD -c 'consul config write ${OUTPUT_FOLDER}global/intention-frontend.hcl'

#### TAB ._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._
md_log "#### API == transform to TAB == " 
# ._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._

md_log 'Use the [/v1/config](/consul/api-docs/config#apply-configuration) API endpoint to apply the intentions.'

md_log 'Create the intentions for the `hashicups-db` service.'

_RUN_CMD -h 'curl --silent \
  --header "X-Consul-Token: $CONSUL_HTTP_TOKEN" \
  --connect-to server.${CONSUL_DATACENTER}.${CONSUL_DOMAIN}:8443:consul-server-0:8443 \
  --cacert ${CONSUL_CACERT} \
  --data @${OUTPUT_FOLDER}global/intention-db.json \
  --request PUT \
  https://server.${CONSUL_DATACENTER}.${CONSUL_DOMAIN}:8443/v1/config'

md_log 'The command returns `true` on success.'

md_log 'Create the intentions for the `hashicups-api` service.'

_RUN_CMD -h 'curl --silent \
  --header "X-Consul-Token: $CONSUL_HTTP_TOKEN" \
  --connect-to server.${CONSUL_DATACENTER}.${CONSUL_DOMAIN}:8443:consul-server-0:8443 \
  --cacert ${CONSUL_CACERT} \
  --data @${OUTPUT_FOLDER}global/intention-api.json \
  --request PUT \
  https://server.${CONSUL_DATACENTER}.${CONSUL_DOMAIN}:8443/v1/config'

md_log 'The command returns `true` on success.'

md_log 'Create the intentions for the `hashicups-frontend` service.'

_RUN_CMD -h 'curl --silent \
  --header "X-Consul-Token: $CONSUL_HTTP_TOKEN" \
  --connect-to server.${CONSUL_DATACENTER}.${CONSUL_DOMAIN}:8443:consul-server-0:8443 \
  --cacert ${CONSUL_CACERT} \
  --data @${OUTPUT_FOLDER}global/intention-frontend.json \
  --request PUT \
  https://server.${CONSUL_DATACENTER}.${CONSUL_DOMAIN}:8443/v1/config'

md_log 'The command returns `true` on success.'

### H3 .........................................................................
md_h3 "Apply global configuration" 
# ..............................................................................  

md_log 'To make sure Consul service mesh recognizes services correctly, apply global configuration to your datacenter.'

#### TAB  ._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._
md_log "#### CLI == transform to TAB == " 
# ._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._

md_log 'Use `consul config write` to apply the configuration.'

_RUN_CMD -c 'consul config write ${OUTPUT_FOLDER}global/config-global-proxy-default.hcl'

_RUN_CMD -c 'consul config write ${OUTPUT_FOLDER}global/config-hashicups-db-service-defaults.hcl'

#### TAB  ._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._
md_log "#### API == transform to TAB == " 
# ._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._

md_log 'Use the [/v1/config](/consul/api-docs/config#apply-configuration) API endpoint to apply the intentions.'

_RUN_CMD -h 'curl --silent \
  --header "X-Consul-Token: $CONSUL_HTTP_TOKEN" \
  --connect-to server.${CONSUL_DATACENTER}.${CONSUL_DOMAIN}:8443:consul-server-0:8443 \
  --cacert ${CONSUL_CACERT} \
  --data @${OUTPUT_FOLDER}global/config-global-proxy-default.json \
  --request PUT \
  https://server.${CONSUL_DATACENTER}.${CONSUL_DOMAIN}:8443/v1/config'

_RUN_CMD -h 'curl --silent \
  --header "X-Consul-Token: $CONSUL_HTTP_TOKEN" \
  --connect-to server.${CONSUL_DATACENTER}.${CONSUL_DOMAIN}:8443:consul-server-0:8443 \
  --cacert ${CONSUL_CACERT} \
  --data @${OUTPUT_FOLDER}global/config-hashicups-db-service-defaults.json \
  --request PUT \
  https://server.${CONSUL_DATACENTER}.${CONSUL_DOMAIN}:8443/v1/config'



##  H2 -------------------------------------------------------------------------
md_h2 "Register services in Consul service mesh"
# ------------------------------------------------------------------------------

md_log 'To register services in Consul service mesh you need to change the service definition file.'

md_log 'Copy the service configuration files generated in the previous tutorial to the remote nodes.'

md_log 'First, configure the Consul configuration directory.'

_RUN_CMD -h 'export CONSUL_REMOTE_CONFIG_DIR=/etc/consul.d/'
export CONSUL_REMOTE_CONFIG_DIR=/etc/consul.d/

## =============================================================================
## =============================================================================

NODES_ARRAY=( "hashicups-db" "hashicups-api" "hashicups-frontend" "hashicups-nginx" )
NAMES_ARRAY=( "Database" "API" "Frontend" "NGINX" )

_name_count=0

for node in "${NODES_ARRAY[@]}"; do

  ### H3 .........................................................................
  md_h3 "Copy configuration for ${NAMES_ARRAY[$_name_count]}" 
  # ..............................................................................  

  NUM="${node/-/_}""_NUMBER"
  
  for i in `seq ${!NUM}`; do

    NODE_NAME="${node}-$((i-1))"

    if [ "${!NUM}" -gt 1 ]; then
      #### H4 ._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._
      md_log "#### Copy configuration on ${NODE_NAME}" 
      # ._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._
    fi

    md_log 'Use `rsync` to copy the service configuration file into the remote node.'

    _RUN_CMD 'rsync -av \
 	-e "ssh -i ~/certs/id_rsa" \
 	${OUTPUT_FOLDER}'${NODE_NAME}'/svc/service_mesh/svc-'${node}.hcl' \
 	'${NODE_NAME}':${CONSUL_REMOTE_CONFIG_DIR}/svc.hcl'

  done

  _name_count=`expr ${_name_count} + 1`

done

sleep 5 

## =============================================================================
## =============================================================================

##  H2 -------------------------------------------------------------------------
md_h2 "Start sidecar proxies for services"
# ------------------------------------------------------------------------------

md_log "Once you copied the configuration files on the different VMs, login on 
each Consul client VMs and start the Envoy sidecar proxy for the agent."

## =============================================================================
## =============================================================================

# NODES_ARRAY=( "hashicups-db" "hashicups-api" "hashicups-frontend" "hashicups-nginx" )
# NAMES_ARRAY=( "Database" "API" "Frontend" "NGINX" )

_name_count=0

for node in "${NODES_ARRAY[@]}"; do

  ### H3 .........................................................................
  md_h3 "Start sidecar proxy for ${NAMES_ARRAY[$_name_count]}" 
  # ..............................................................................  

  NUM="${node/-/_}""_NUMBER"
  
  for i in `seq ${!NUM}`; do

    NODE_NAME="${node}-$((i-1))"

    if [ "${!NUM}" -gt 1 ]; then
      #### H4 ._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._
      md_log "#### Start sidecar proxy for ${NODE_NAME}" 
      # ._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._
    fi

    _CONNECT_TO ${NODE_NAME}

    md_log 'Define the Consul configuration directory.'

    _RUN_CMD -h 'export CONSUL_CONFIG_DIR=/etc/consul.d/'
    export CONSUL_CONFIG_DIR=/etc/consul.d/

    md_log 'Setup a valid token to interact with Consul agent.'

    _RUN_CMD -h 'export CONSUL_HTTP_TOKEN=`cat ${CONSUL_CONFIG_DIR}/agent-acl-tokens.hcl | grep agent | awk '\''{print $3}'\''| sed '\''s/"//g'\''`'

    md_log 'Finally, start the Envoy sidecar proxy for the service.'

    _RUN_CMD -r ${NODE_NAME} -e "CONSUL_HTTP_TOKEN" '/usr/bin/consul connect envoy \
   -token=${CONSUL_HTTP_TOKEN} \
  -envoy-binary /usr/bin/envoy \
  -sidecar-for '"${NODE_NAME}"' > /tmp/sidecar-proxy.log 2>&1 &'

    md_log "The command starts the Envoy sidecar proxy in the background to not 
lock the terminal. You can access the Envoy log through the "'`/tmp/sidecar-proxy.log`'" file. "

    _EXIT_FROM ${NODE_NAME}

  done

  _name_count=`expr ${_name_count} + 1`

done

##  H2 -------------------------------------------------------------------------
md_h2 'Restart services to listen on `localhost`'
# ------------------------------------------------------------------------------

md_log "Now that the service configuration is applied, intentions are applied, 
and Envoy sidecars are started for each service, all the components for the 
Consul service mesh are in place. The Consul sidecar proxies will route the 
services' traffic to the target destination. "

md_log 'Since traffic is flowing through the sidecar proxies, you no longer 
need to expose your services externally. As a result, reconfigure them to listen 
on the loopback interface only to improve overall security.'

md_log 'Reload the services to operate on the `localhost` interface.'

## =============================================================================
## =============================================================================

# NODES_ARRAY=( "hashicups-db" "hashicups-api" "hashicups-frontend" "hashicups-nginx" )
# NAMES_ARRAY=( "Database" "API" "Frontend" "NGINX" )

_name_count=0

_COMPOSED_COMMAND=''

for node in "${NODES_ARRAY[@]}"; do

  _start_param="--local"

  if [ "${node}" == "hashicups-nginx" ]; then
    _start_param="--ingress"
  fi


  NUM="${node/-/_}""_NUMBER"
  
  for i in `seq ${!NUM}`; do

    NODE_NAME="${node}-$((i-1))"

    if [ "test${_COMPOSED_COMMAND}" == "test" ]; then

      _COMPOSED_COMMAND='ssh -i ~/certs/id_rsa '${NODE_NAME}' "bash -c '\''bash ./start_service.sh start '${_start_param}''\''";'

    else
      
      _COMPOSED_COMMAND=${_COMPOSED_COMMAND}' \
  ssh -i ~/certs/id_rsa '${NODE_NAME}' "bash -c '\''bash ./start_service.sh start '${_start_param}''\''";'

    fi

  done

  _name_count=`expr ${_name_count} + 1`

done

_RUN_CMD "${_COMPOSED_COMMAND}"

md_log "This tutorial still configures the NGINX service to listen on the VM's 
IP so you can still access it remotely. For production, we recommend using an 
[ingress gateway](/consul/tutorials/developer-mesh/service-mesh-ingress-gateways) to manage access to the service."
