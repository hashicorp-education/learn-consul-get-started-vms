#!/usr/bin/env bash

# ++-----------------+
# || Functions       |
# ++-----------------+

# ++-----------------+
# || Variables       |
# ++-----------------+

username=${username:-$(whoami)}

export STEP_ASSETS="${SCENARIO_OUTPUT_FOLDER}conf/"


SCENARIO_NAME="GS_02_service_discovery"
export MD_RUNBOOK_FILE="/home/${username}/runbooks/self_managed-${SCENARIO_CLOUD_PROVIDER}-${SCENARIO_NAME}-runbook.md"

## Remove previous runbook files if any
rm -rf ${MD_RUNBOOK_FILE}

## Make sure folder exists
mkdir -p "/home/${username}/runbooks"

sudo chown ${USERNAME} /home/${username}/runbooks

## Configuring Consul DNS port. Not printing this in the MD file.
export CONSUL_DNS_PORT="53"

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

# H1 ===========================================================================
md_h1 "Register your services to Consul"
# ==============================================================================

md_log "This is a solution runbook for the scenario deployed."

##  H2 -------------------------------------------------------------------------
md_h2 "Prerequisites"
# ------------------------------------------------------------------------------

md_log "Log into the bastion host using ssh."

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

##  H2 -------------------------------------------------------------------------
md_h2 "Configure environment"
# ------------------------------------------------------------------------------

md_log "The lab contains two environment files that will help you configure the 
terminal and generate the required configuration files."

_RUN_CMD -c 'ls -1 ~/assets/scenario/env*.env'

md_log "Source the files to set the variables in the terminal session."

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
md_h2 "Generate Consul clients configuration"
# ------------------------------------------------------------------------------

md_log "Since the Consul datacenter is configured with ACL enabled by default, 
you will need to define the ACL tokens you want to pass to the Consul clients 
when the configuration gets created."

md_log "First, export the token you generated for DNS so you can use it as default token for clients."

_RUN_CMD -h 'export CONSUL_DNS_TOKEN=`cat ${OUTPUT_FOLDER}secrets/acl-token-dns.json | jq -r ".SecretID"`'
export CONSUL_DNS_TOKEN=`cat ${OUTPUT_FOLDER}secrets/acl-token-dns.json | jq -r ".SecretID"`

md_log "Then, for Consul service definition to be created properly, 
define a Consul token to be included in the service definition file."

md_log "In this example, you will use the bootstrap token."

_RUN_CMD -h 'export CONSUL_AGENT_TOKEN="${CONSUL_HTTP_TOKEN}"'
export CONSUL_AGENT_TOKEN="${CONSUL_HTTP_TOKEN}"

## =============================================================================
## =============================================================================

NODES_ARRAY=( "hashicups-db" "hashicups-api" "hashicups-frontend" "hashicups-nginx" )
NAMES_ARRAY=( "Database" "API" "Frontend" "NGINX" )

_name_count=0

for node in "${NODES_ARRAY[@]}"; do

  ### H3 .........................................................................
  md_h3 "Generate configuration for ${NAMES_ARRAY[$_name_count]}" 
  # ..............................................................................  

  NUM="${node/-/_}""_NUMBER"
  
  for i in `seq ${!NUM}`; do

    NODE_NAME="${node}-$((i-1))"

    if [ "${!NUM}" -gt 1 ]; then
      #### H4 ._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._
      md_log "#### Generate configuration for ${NODE_NAME}" 
      # ._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._
    fi

    md_log "First, define the Consul node name."

    _RUN_CMD -h 'export NODE_NAME="'${NODE_NAME}'"'
    export NODE_NAME=${NODE_NAME}

    md_log "Then, generate the Consul configuration."

    # pushd ${HOME} > /dev/null 2>&1

    export COLORED_OUTPUT=false
    export PREPEND_DATE=false

    ## [cmd] [script] generate_consul_client_config.sh
    _RUN_CMD -c "~/ops/scenarios/00_base_scenario_files/supporting_scripts/generate_consul_client_config.sh"

    # popd

    md_log "To complete Consul agent configuration, you need to set up tokens 
for the client. For this tutorial, you are using the bootstrap token. 
We recommend you to create more restrictive tokens for the client agents in production."

    _RUN_CMD -h 'tee ${OUTPUT_FOLDER}${NODE_NAME}/agent-acl-tokens.hcl > /dev/null << EOF
acl {
  tokens {
    agent  = "${CONSUL_HTTP_TOKEN}"
    default  = "${CONSUL_DNS_TOKEN}"
    config_file_service_registration = "${CONSUL_HTTP_TOKEN}"
  }
}
EOF'

    md_log "Once Consul agent configuration is generated, you can copy the configuration to the remote node."

    md_log "First, define the Consul configuration directory."

    _RUN_CMD -h 'export CONSUL_REMOTE_CONFIG_DIR=/etc/consul.d/'
    export CONSUL_REMOTE_CONFIG_DIR=/etc/consul.d/

    md_log "Then, remove existing configuration from the VM."

    _RUN_CMD -h 'ssh -i ~/certs/id_rsa ${NODE_NAME} "sudo rm -rf ${CONSUL_REMOTE_CONFIG_DIR}*"'

    md_log 'Finally, use `rsync` to copy the configuration files into the remote node.'

    _RUN_CMD 'rsync -av \
 	-e "ssh -i ~/certs/id_rsa" \
 	${OUTPUT_FOLDER}${NODE_NAME}/ \
 	${NODE_NAME}:${CONSUL_REMOTE_CONFIG_DIR}'

  done

  _name_count=`expr ${_name_count} + 1`

done

##  H2 -------------------------------------------------------------------------
md_h2 "Start Consul on client nodes"
# ------------------------------------------------------------------------------

md_log "Now that you have copied the configuration files to each client VMs, 
start the Consul client agent on each VM."

_name_count=0

for node in "${NODES_ARRAY[@]}"; do

  ### H3 .......................................................................
  md_h3 "Start Consul on ${NAMES_ARRAY[$_name_count]}" 
  # ............................................................................  

  NUM="${node/-/_}""_NUMBER"
  
  for i in `seq ${!NUM}`; do

    NODE_NAME="${node}-$((i-1))"

    if [ "${!NUM}" -gt 1 ]; then
      #### H4 ._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._
      md_log "#### Start Consul on ${NODE_NAME}" 
      # ._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._
    fi

    md_log "Log into the ${NAMES_ARRAY[$_name_count]} VM from the bastion host."

    _CONNECT_TO ${NODE_NAME}

    md_log "Ensure your user has write permission to the Consul data directory."

    _RUN_CMD -r ${NODE_NAME} -h 'sudo chmod g+w /opt/consul/'

    md_log "Finally, start the Consul client process."

    _RUN_CMD -r ${NODE_NAME} -h 'consul agent -config-dir=/etc/consul.d/ > /tmp/consul-client.log 2>&1 &'

    md_log 'The command starts the Consul server in the background to not lock the terminal. You can access the Consul server log through the `/tmp/consul-client.log` file.'

    _EXIT_FROM ${NODE_NAME}

  done

  _name_count=`expr ${_name_count} + 1`

done

##  H2 -------------------------------------------------------------------------
md_h2 "Verify Consul datacenter members"
# ------------------------------------------------------------------------------

md_log "After you started all Consul agents, verify they successfully joined the Consul datacenter."

#### TAB ._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._
md_log "#### CLI == transform to TAB == " 
# ._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._

md_log 'Retrieve the agents in the Consul datacenter.'

_RUN_CMD -c 'consul members'

#### TAB ._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._
md_log "#### API == transform to TAB == " 
# ._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._

md_log 'Use the [/v1/agent/members](/consul/api-docs/agent#list-members) API endpoint to retrieve the agents in the Consul datacenter.'

_RUN_CMD -o json 'curl --silent \
  --header "X-Consul-Token: $CONSUL_HTTP_TOKEN" \
  --connect-to server.${CONSUL_DATACENTER}.${CONSUL_DOMAIN}:8443:consul-server-0:8443 \
  --cacert ${CONSUL_CACERT} \
  https://server.${CONSUL_DATACENTER}.${CONSUL_DOMAIN}:8443/v1/agent/members | jq'

##  H2 -------------------------------------------------------------------------
md_h2 "Register services in the Consul catalog"
# ------------------------------------------------------------------------------

md_log "Once Consul client agents are running it is time to add services to the Consul catalog.
This will make the services discoverable through the Consul interfaces."

_name_count=0

for node in "${NODES_ARRAY[@]}"; do

  ### H3 .......................................................................
  md_h3 "Register the ${NAMES_ARRAY[$_name_count]} service" 
  # ............................................................................  

  NUM="${node/-/_}""_NUMBER"
  
  for i in `seq ${!NUM}`; do

    NODE_NAME="${node}-$((i-1))"

    if [ "${!NUM}" -gt 1 ]; then
      #### H4 ._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._
      md_log "#### Register the service on ${NODE_NAME}" 
      # ._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._
    fi
  
    md_log "First, define the Consul node name."

    _RUN_CMD -h 'export NODE_NAME="'${NODE_NAME}'"'
    
    md_log "Then, generate the service configuration for the node."

    export COLORED_OUTPUT=false
    export PREPEND_DATE=false

    ## [cmd] [script] generate_hashicups_service_config.sh
    _RUN_CMD -c "~/ops/scenarios/00_base_scenario_files/supporting_scripts/generate_hashicups_service_config.sh"

    md_log "Finally, copy the service definition file into the remote node."

    _RUN_CMD 'rsync -av \
 	-e "ssh -i ~/certs/id_rsa" \
 	${OUTPUT_FOLDER}${NODE_NAME}/svc/service_discovery/svc'-${node}'.hcl \
 	${NODE_NAME}:${CONSUL_REMOTE_CONFIG_DIR}/svc.hcl'

  done

  _name_count=`expr ${_name_count} + 1`

done

## Give time for services to settle
sleep 5 

##  H2 -------------------------------------------------------------------------
md_h2 "Query services in Consul catalog"
# ------------------------------------------------------------------------------

md_log "Query the healthy services using the Consul CLI, API, or DNS."

#### TAB ._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._
md_log "#### CLI == transform to TAB == " 
# ._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._

md_log "Use the Consul CLI to query the service catalog."

_RUN_CMD -c 'consul catalog services -tags'

#### TAB ._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._
md_log "#### API == transform to TAB == " 
# ._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._

md_log "Use the [/v1/catalog/services](/consul/api-docs/catalog#list-services) API endpoint to get a list of the services in the Consul catalog."

_RUN_CMD -o json 'curl --silent \
  --header "X-Consul-Token: $CONSUL_HTTP_TOKEN" \
  --connect-to server.${CONSUL_DATACENTER}.${CONSUL_DOMAIN}:8443:consul-server-0:8443 \
  --cacert ${CONSUL_CACERT} \
  https://server.${CONSUL_DATACENTER}.${CONSUL_DOMAIN}:8443/v1/catalog/services | jq'

md_log 'The output shows the tags (`v1`) associated with each service instance.'

md_log 'If you want more information on a specific service, use the [/v1/catalog/service/:service](consul/api-docs/catalog#list-nodes-for-service) API endpoint.'

md_log 'Retrieve more information about the database service.'

_RUN_CMD -o json 'curl --silent \
  --header "X-Consul-Token: $CONSUL_HTTP_TOKEN" \
  --connect-to server.${CONSUL_DATACENTER}.${CONSUL_DOMAIN}:8443:consul-server-0:8443 \
  --cacert ${CONSUL_CACERT} \
  https://server.${CONSUL_DATACENTER}.${CONSUL_DOMAIN}:8443/v1/catalog/service/hashicups-db | jq'

#### TAB ._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._
md_log "#### DNS == transform to TAB == " 
# ._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._

md_log "Use the Consul DNS service to resolve the service name into an IP address. 
Consul uses "'`SERVICE_NAME.service.DATACENTER.DOMAIN`'" format to query services."

md_log "Retrieve the database service's IP address."

_RUN_CMD -c 'dig @consul-server-0 -p '${CONSUL_DNS_PORT}' hashicups-db.service.dc1.consul ANY'

##  H2 -------------------------------------------------------------------------
md_h2 "Modify service definition tags"
# ------------------------------------------------------------------------------

md_log "When using Consul CLI or the API endpoints, Consul will also show you 
the metadata associated with the services. In this tutorial, you registered each 
service with the "'`v1`'" tag."

md_log "In this section, you will update the database service definition to 
learn how to update Consul service definitions. You must run these commands on 
the virtual machine that hosts the services."

md_log 'Edit the service definition file for the **Database** service to add a `v2` tag to the service.'

_RUN_CMD 'sed '\'s'/"v1"/"v1","v2"/'\'' \
  ${OUTPUT_FOLDER}hashicups-db-0/svc/service_discovery/svc-hashicups-db.hcl \
  > ${OUTPUT_FOLDER}hashicups-db-0/svc/service_discovery/svc-hashicups-db-multi-tag.hcl'

md_log 'Review the file to verify the change was applied.'

_RUN_CMD -c 'cat ${OUTPUT_FOLDER}hashicups-db-0/svc/service_discovery/svc-hashicups-db-multi-tag.hcl'

md_log "Finally, copy the service definition file into the remote node to apply the change."

_RUN_CMD 'rsync -av \
 	-e "ssh -i ~/certs/id_rsa" \
 	${OUTPUT_FOLDER}hashicups-db-0/svc/service_discovery/svc-hashicups-db-multi-tag.hcl \
 	hashicups-db-0:${CONSUL_REMOTE_CONFIG_DIR}svc.hcl'

sleep 5

##  H2 -------------------------------------------------------------------------
md_h2 "Query services by tags"
# ------------------------------------------------------------------------------

md_log After you have updated the database service definition, query it to verify the new tag.

#### TAB ._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._
md_log "#### CLI == transform to TAB == " 
# ._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._

md_log 'Retrieve the tags associated with each service and verify the new `v2` tag for the database service.'

_RUN_CMD -c 'consul catalog services -tags'

#### TAB ._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._
md_log "#### API == transform to TAB == " 
# ._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._

md_log "Use the [/v1/catalog/services](/consul/api-docs/catalog#list-services) 
API endpoint to get a list of the services in the Consul catalog and verify the 
new "'`v2`'" tag for the database service."

_RUN_CMD -o json 'curl --silent \
  --header "X-Consul-Token: $CONSUL_HTTP_TOKEN" \
  --connect-to server.${CONSUL_DATACENTER}.${CONSUL_DOMAIN}:8443:consul-server-0:8443 \
  --cacert ${CONSUL_CACERT} \
  https://server.${CONSUL_DATACENTER}.${CONSUL_DOMAIN}:8443/v1/catalog/services | jq'

#### TAB ._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._
md_log "#### DNS == transform to TAB == " 
# ._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._

md_log "The DNS service does not expose the tags information, since tags are an 
internal Consul metadata. Consul exposes the tags as a subdomain associated 
with the service in the form: "'`TAG.SERVICE_NAME.service.DATACENTER.DOMAIN`'"."

md_log "Retrieve the database service's IP address using the "'`v2`'" tag."

_RUN_CMD -c 'dig @consul-server-0 -p '${CONSUL_DNS_PORT}' v2.hashicups-db.service.dc1.consul ANY'

## =============================================================================
## =============================================================================
