#!/usr/bin/env bash

# ++-----------------+
# || Functions       |
# ++-----------------+

# ++-----------------+
# || Variables       |
# ++-----------------+

username=${username:-$(whoami)}

export STEP_ASSETS="${SCENARIO_OUTPUT_FOLDER}conf/"


SCENARIO_NAME="GS_01_deploy_consul_on_vms"
export MD_RUNBOOK_FILE="/home/${username}/runbooks/self_managed-${SCENARIO_CLOUD_PROVIDER}-${SCENARIO_NAME}-runbook.md"

## Remove previous runbook files if any
rm -rf ${MD_RUNBOOK_FILE}

## Make sure folder exists
mkdir -p "/home/${username}/runbooks"

# ++-----------------+
# || Begin           |
# ++-----------------+

# H1 ===========================================================================
md_h1 "Deploy Consul on VMs"
# ==============================================================================

md_log "This is a solution runbook for the scenario deployed."

##  H2 -------------------------------------------------------------------------
md_h2 "Prerequisites"
# ------------------------------------------------------------------------------

md_log "Login to the bastion host using ssh."

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
md_h3 "Verify Consul binary" 
# ..............................................................................

md_log "Verify that the VM you want to deploy the Consul server on has the Consul binary."

_RUN_CMD -c 'consul version'    

_STAT="$?"

if [ "${_STAT}" -ne 0 ];  then
  log_err "Consul command not found."
  exit 254
fi

##  H2 -------------------------------------------------------------------------
md_h2 "Generate Consul server configuration"
# ------------------------------------------------------------------------------

md_log "On the bastion host, verify that the scripts are correctly present in the home directory of the user."

_RUN_CMD -c 'tree ~/ops/scenarios/00_base_scenario_files/supporting_scripts/'

md_log "The scripts rely on default parameters to generate the configuration files. Set the following default values. Ensure you have permission to write in the specified paths."

_RUN_CMD -h 'export CONSUL_DOMAIN=${DOMAIN} \
  export CONSUL_DATACENTER=${DATACENTER} \
  export CONSUL_SERVER_NUMBER=${SERVER_NUMBER} \
  export CONSUL_DATA_DIR=/opt/consul \
  export CONSUL_CONFIG_DIR=/etc/consul.d/ \
  export CONSUL_RETRY_JOIN=consul-server-0'

export CONSUL_DOMAIN=${CONSUL_DOMAIN}
export CONSUL_DATACENTER=${CONSUL_DATACENTER}
export CONSUL_SERVER_NUMBER=${CONSUL_SERVER_NUMBER}
export CONSUL_DATA_DIR="/opt/consul"
export CONSUL_CONFIG_DIR="/etc/consul.d/"
# export CONSUL_RETRY_JOIN="consul-server-0"

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

md_log "A Consul datacenter is composed by multiple nodes that, at startup, connect with each other using the Gossip protocol. 
To be able to automatically locate other nodes at startup, Consul configuration needs a retry_join parameter.
"

_RUN_CMD -h "export CONSUL_RETRY_JOIN=consul-server-0"
# export CONSUL_RETRY_JOIN="consul-server-0"
export CONSUL_RETRY_JOIN

md_log "The script creates all the files in a destination folder. Export the path where you wish to create the configuration files for the scenario."

_RUN_CMD -h "export OUTPUT_FOLDER=${STEP_ASSETS}"
export OUTPUT_FOLDER="${STEP_ASSETS}"

md_log "Make sure the folder exists."

_RUN_CMD -h 'mkdir -p ${OUTPUT_FOLDER}'

md_log "Generate all necessary files to configure and run the Consul server agent."

export COLORED_OUTPUT=false
export PREPEND_DATE=false

## [cmd] [script] generate_consul_server_config.sh
_RUN_CMD -c "~/ops/scenarios/00_base_scenario_files/supporting_scripts/generate_consul_server_config.sh"

md_log "When the script completes, list the generated files."

_RUN_CMD -c 'tree ${OUTPUT_FOLDER}'

### H3 .........................................................................
md_h3 "Test configuration" 
# ..............................................................................

for i in `seq 0 "$((CONSUL_SERVER_NUMBER-1))"`; do

  md_log 'Verify the configuration generated for `'consul-server-$i'` is valid. Despite the `INFO` messages, the Consul configuration files are valid.'

  _RUN_CMD -c 'consul validate ${OUTPUT_FOLDER}/consul-server-'$i

done

### H3 .........................................................................
md_h3 "Copy configuration on Consul server node" 
# ..............................................................................

for i in `seq 0 "$((CONSUL_SERVER_NUMBER-1))"`; do

  md_log 'Copy the configuration files to the `'consul-server-$i'` VM.'

  md_log "First, configure the Consul configuration directory."

  _RUN_CMD -h "export CONSUL_REMOTE_CONFIG_DIR=/etc/consul.d/"
  export CONSUL_REMOTE_CONFIG_DIR=/etc/consul.d/

  md_log "Then, remove existing configuration from the server."

  _RUN_CMD -h 'ssh -i certs/id_rsa consul-server-'$i' "sudo rm -rf ${CONSUL_REMOTE_CONFIG_DIR}*"'

  # _RUN_CMD -c 'ssh -i certs/id_rsa consul-server-0 "sudo tree /etc"'

  md_log 'Finally, use `rsync` to copy the configuration into the server node. '

  _RUN_CMD 'rsync -av \
 	-e "ssh -i ~/certs/id_rsa" \
 	${OUTPUT_FOLDER}consul-server-'$i'/ \
 	consul-server-'$i':${CONSUL_REMOTE_CONFIG_DIR}'

done

##  H2 -------------------------------------------------------------------------
md_h2 "Start Consul server"
# ------------------------------------------------------------------------------

for i in `seq 0 "$((CONSUL_SERVER_NUMBER-1))"`; do

  if [ "${CONSUL_SERVER_NUMBER}" -gt 1 ]; then

    ## Prints h3 headers only in case there is more than one server node

    ### H3 .........................................................................
    md_log '### Start Consul on `'consul-server-$i'` VM.'
    # ..............................................................................

  fi

  _CONNECT_TO consul-server-$i

  md_log "Make sure your user has write permissions in the Consul data directory."

  _RUN_CMD -r consul-server-$i -h 'sudo chmod g+w /opt/consul/'

  md_log "Finally, start the Consul server process."

  # _RUN_CMD -r consul-server-$i -h 'consul agent -config-dir=/etc/consul.d/ > /tmp/consul-server.log 2>&1 &'
  _RUN_CMD -r consul-server-$i -h 'consul agent -config-dir=/etc/consul.d/ > /tmp/consul-server.log 2>&1 &'

  md_log 'The command starts the Consul server in the background to not lock the terminal. 
  You can access the Consul server log through the `/tmp/consul-server.log` file.'

  # sleep 10

  _RUN_CMD -r consul-server-$i -c 'cat /tmp/consul-server.log'

  ## [bug] for some reason this command alwys prints an error no matter how much we sleep
  ## still Consul stats successfully  
  ## ```shell-session
  ## $ cat /tmp/consul-server.log
  ## ==> data_dir cannot be empty
  ## ```

  _EXIT_FROM consul-server-$i

done

##  H2 -------------------------------------------------------------------------
md_h2 "Configure Consul CLI to interact with Consul server"
# ------------------------------------------------------------------------------

md_log "In order to interact with the Consul server, you need to setup your terminal."

md_log "Make sure scenario environment variables are still defined."

_RUN_CMD -h 'export CONSUL_DOMAIN='${CONSUL_DOMAIN}' \
  export CONSUL_DATACENTER='${CONSUL_DATACENTER}' \
  export OUTPUT_FOLDER='${STEP_ASSETS}''

export CONSUL_DOMAIN=${CONSUL_DOMAIN}
export CONSUL_DATACENTER=${CONSUL_DATACENTER}
export OUTPUT_FOLDER=${STEP_ASSETS}

md_log "Configure the Consul CLI to interact with the Consul server."

_RUN_CMD -h 'export CONSUL_HTTP_ADDR="https://consul-server-0:8443" \
  export CONSUL_HTTP_SSL=true \
  export CONSUL_CACERT="${OUTPUT_FOLDER}secrets/consul-agent-ca.pem" \
  export CONSUL_TLS_SERVER_NAME="server.${CONSUL_DATACENTER}.${CONSUL_DOMAIN}"'

export CONSUL_HTTP_ADDR="https://consul-server-0:8443"
export CONSUL_HTTP_SSL=true
export CONSUL_CACERT="${OUTPUT_FOLDER}secrets/consul-agent-ca.pem"
export CONSUL_TLS_SERVER_NAME="server.${CONSUL_DATACENTER}.${CONSUL_DOMAIN}"

##  H2 -------------------------------------------------------------------------
md_h2 "Bootstrap ACLs"
# ------------------------------------------------------------------------------

md_log "Verify that the Consul CLI can reach your Consul server."

_RUN_CMD -c "consul info"

md_log "The output informs you that while the Consul CLI can reach your Consul server, Consul's ACLs are blocking the request."

md_log 'Bootstrap the Consul ACL system and save the output in a file named `acl-token-bootstrap.json`.'

if [ "${CONSUL_SERVER_NUMBER}" -gt 0 ]; then

  for i in `seq 1 9`; do

    consul acl bootstrap --format json > ${OUTPUT_FOLDER}secrets/acl-token-bootstrap.json
    
    excode=$?

    if [ ${excode} -eq 0 ]; then

      md_log_cmd -s shell-session "consul acl bootstrap --format json | tee ./acl-token-bootstrap.json
`cat ${OUTPUT_FOLDER}secrets/acl-token-bootstrap.json`"

      break;
    else
      if [ $i -eq 9 ]; then
        log_err "Failed to bootstrap ACL system, exiting."
        exit 1
      else
        log_warn "ACL system not ready. Retrying...";
        sleep 5;
      fi
    fi
  done

else

  _RUN_CMD -c "consul acl bootstrap --format json | tee ${OUTPUT_FOLDER}secrets/acl-token-bootstrap.json"

fi

md_log 'The command generates a management token with full permissions over your datacenter. 
The management token is the value associated with the `SecretID` key.'

md_log 'Extract the management token from the file and set it to the `CONSUL_HTTP_TOKEN` environment variable.'

_RUN_CMD -h 'export CONSUL_HTTP_TOKEN=`cat ./acl-token-bootstrap.json | jq -r ".SecretID"`'
export CONSUL_HTTP_TOKEN=`cat ${OUTPUT_FOLDER}secrets/acl-token-bootstrap.json | jq -r ".SecretID"`

md_log "Now that you have bootstrapped the ACL system, you can interact with the Consul server."

_RUN_CMD -c "consul info"

##  H2 -------------------------------------------------------------------------
md_h2 "Create server tokens"
# ------------------------------------------------------------------------------

md_log "The Consul datacenter is now fully bootstrapped and is ready to receive requests."

### H3 .........................................................................
md_h3 "Automated - move into TAB" 
# ..............................................................................

md_log "In order to complete configuring the Consul server, you need to create the tokens for the server agents and assign them to the server."

md_log 'The `generate_consul_sever_tokens.sh` script automates the process of creating policies and tokens for your Consul server. This script generates ACL policies for Consul DNS service and for the server agent and applies them to the Consul server.'

md_log 'In the terminal with your bastion host, run the `generate_consul_server_tokens.sh` script to create the ACL policies and tokens for your Consul server.'

export COLORED_OUTPUT=false
export PREPEND_DATE=false

## [cmd] [script] generate_consul_server_tokens.sh
_RUN_CMD -c '~/ops/scenarios/00_base_scenario_files/supporting_scripts/generate_consul_server_tokens.sh'

md_log 'After you create the server tokens, your Consul logs will show the updated ACL tokens.'


## =============================================================================
## =============================================================================

## Clean configuration to test the manual process.
## The commands in this section do not make into the runbook.

## Remove token

DNS_TOKEN_ID=`cat ${OUTPUT_FOLDER}/secrets/acl-token-dns.json | jq -r ".AccessorID"`;

consul acl token delete DNS_TOKEN_ID

for i in `seq 0 "$((CONSUL_SERVER_NUMBER-1))"`; do

  SERVER_TOKEN_ID=`cat ${OUTPUT_FOLDER}/secrets/consul-server-$i-acl-token.json | jq -r ".AccessorID"`

  consul acl token delete SERVER_TOKEN_ID

done

consul acl policy delete -name acl-policy-dns
consul acl policy delete -name acl-policy-server-node

## Remove configuration files
rm -f ${OUTPUT_FOLDER}/secrets/acl-token-dns.json
rm -f ${OUTPUT_FOLDER}/secrets/consul-server-*-acl-token.json

rm -f ${OUTPUT_FOLDER}/acl-policy*

## =============================================================================
## =============================================================================

### H3 .........................................................................
md_h3 "Manual - move into TAB" 
# ..............................................................................

md_log "You will create ACL tokens for the Consul DNS service and your server agent. For each token, you will:"

md_log "
1. define the policy configuration file,
1. create the Consul policy,
1. create the ACLs token for the policy,
1. assign the token to the server agent.
"

### H3 .........................................................................
md_h3 "Define the policy configuration files" 
# ..............................................................................

md_log "First, define the DNS policy file."

_RUN_CMD 'tee ./acl-policy-dns.hcl > /dev/null << EOF
## dns-request-policy.hcl
node_prefix "" {
  policy = "read"
}
service_prefix "" {
  policy = "read"
}
# Required if you use prepared queries
query_prefix "" {
  policy = "read"
}
EOF'

md_log "Then, define the server policy file."

_RUN_CMD '
tee ./acl-policy-server-node.hcl > /dev/null << EOF
## consul-server-one-policy.hcl
node_prefix "consul" {
  policy = "write"
}
EOF'

### H3 .........................................................................
md_h3 "Create the Consul policies" 
# ..............................................................................

md_log "First, create the DNS policy using the previously created policy definition."

_RUN_CMD 'consul acl policy create \
  -name "acl-policy-dns" \
  -description "Policy for DNS endpoints" \
  -rules @./acl-policy-dns.hcl'

md_log "Then, create the server policy using the previously created policy definition."

_RUN_CMD 'consul acl policy create \
  -name "acl-policy-server-node" \
  -description "Policy for Server nodes" \
  -rules @./acl-policy-server-node.hcl'

### H3 .........................................................................
md_h3 "Create ACL tokens for each policy" 
# ..............................................................................

md_log "First, create the DNS token."

_RUN_CMD -o json 'consul acl token create \
  -description "DNS - Default token" \
  -policy-name acl-policy-dns \
  --format json | tee ./acl-token-dns.json'

md_log "Then, create the server node token."

_RUN_CMD -o json 'consul acl token create \
  -description "server agent token" \
  -policy-name acl-policy-server-node  \
  --format json | tee ./server-acl-token.json'

### H3 .........................................................................
md_h3 "Assign tokens to the server agent" 
# ..............................................................................

md_log "After you created the tokens, you will now assign them to your Consul agent."

md_log "First, define two environment variables containing the tokens."

_RUN_CMD -h 'export DNS_TOKEN=`cat ./acl-token-dns.json | jq -r ".SecretID"`; \
  export SERVER_TOKEN=`cat ./server-acl-token.json | jq -r ".SecretID"`'

export DNS_TOKEN=`cat ./acl-token-dns.json | jq -r ".SecretID"`; \
export SERVER_TOKEN=`cat ./server-acl-token.json | jq -r ".SecretID"`

# export CONSUL_HTTP_TOKEN=`cat ./acl-token-bootstrap.json | jq -r ".SecretID"`

for i in `seq 0 "$((CONSUL_SERVER_NUMBER-1))"`; do

  if [ "${CONSUL_SERVER_NUMBER}" -gt 1 ]; then

    ## Prints headers only in case there is more than one server node
    md_log '**Setup tokens for `'consul-server-$i'`**'

    md_log "Configure Consul CLI to connect to the correct server."

    _RUN_CMD -h 'export CONSUL_HTTP_ADDR="https://consul-server-'$i':8443"'
    export CONSUL_HTTP_ADDR="https://consul-server-$i:8443"
    
  fi

  md_log "Assign the DNS token to the server."

  _RUN_CMD -c 'consul acl set-agent-token default ${DNS_TOKEN}'

  md_log "Assign the server token to the server. "

  _RUN_CMD -c 'consul acl set-agent-token agent ${SERVER_TOKEN}'

done

## Reset connection string
export CONSUL_HTTP_ADDR="https://consul-server-0:8443"

md_log "After you create the server tokens, your Consul logs will show the updated ACL tokens."

md_log_cmd -s plaintext  -p "## ...
[INFO]  agent: Updated agent's ACL token: token=agent
## ...
[INFO]  agent: Updated agent's ACL token: token=default
## ..."

##  H2 -------------------------------------------------------------------------
md_h2 "Interact with Consul server"
# ------------------------------------------------------------------------------

md_log "Now that you have completed configuring and deploying your Consul server, you will interact with it. 
Consul provides different ways to retrieve information about the datacenter — select the tab(s) for your preferred method."

#### TAB ._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._
md_log "#### CLI == transform to TAB == " 
# ._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._

md_log "Use the Consul CLI to retrieve members in your Consul datacenter."

_RUN_CMD -c 'consul members'

md_log "Check the [Consul CLI commands reference](/consul/commands) for the full list of available commands."

#### TAB ._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._
md_log "#### API == transform to TAB == " 
# ._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._

md_log "Query the Consul API to retrieve members in your Consul datacenter."

_RUN_CMD -o json 'curl --silent \
  --header "X-Consul-Token: $CONSUL_HTTP_TOKEN" \
  --connect-to server.${CONSUL_DATACENTER}.${CONSUL_DOMAIN}:8443:consul-server-0:8443 \
  --cacert ~/assets/scenario/conf/secrets/consul-agent-ca.pem \
  https://server.${CONSUL_DATACENTER}.${CONSUL_DOMAIN}:8443/v1/agent/members | jq'

md_log "Check the [Consul API reference](/consul/api-docs) for the full list of available endpoints."

##  H2 -------------------------------------------------------------------------
md_h2 "Interact with Consul KV"
# ------------------------------------------------------------------------------

md_log "Consul includes a key/value (KV) store that you can use to manage your service's configuration. 
Even though you can use the KV store using the CLI, API, and UI, this tutorial only covers the CLI and API methods. 
Select the tab(s) for your preferred method."

#### TAB ._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._
md_log "#### CLI == transform to TAB == " 
# ._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._

md_log 'Create a key named `db_port` with a value of `5432`.'

_RUN_CMD -c "consul kv put consul/configuration/db_port 5432"

md_log "Then, retrieve the value."

_RUN_CMD -c "consul kv get consul/configuration/db_port"

#### TAB ._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._
md_log "#### API == transform to TAB == " 
# ._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._

md_log 'Create a key named `db_port` with a value of `5432`.'

_RUN_CMD 'curl --silent \
  --header "X-Consul-Token: $CONSUL_HTTP_TOKEN" \
  --connect-to server.${CONSUL_DATACENTER}.${CONSUL_DOMAIN}:8443:consul-server-0:8443 \
  --cacert ~/assets/scenario/conf/secrets/consul-agent-ca.pem \
  --request PUT \
  --data "5432" \
  https://server.${CONSUL_DATACENTER}.${CONSUL_DOMAIN}:8443/v1/kv/consul/configuration/db_port'

md_log "Then, retrieve the value."

_RUN_CMD -o json 'curl --silent \
  --header "X-Consul-Token: $CONSUL_HTTP_TOKEN" \
  --connect-to server.${CONSUL_DATACENTER}.${CONSUL_DOMAIN}:8443:consul-server-0:8443 \
  --cacert ~/assets/scenario/conf/secrets/consul-agent-ca.pem \
  https://server.${CONSUL_DATACENTER}.${CONSUL_DOMAIN}:8443/v1/kv/consul/configuration/db_port | jq'

md_log 'Notice the response returns the `base64` encoded value.'

md_log 'To retrieve the raw value, extract the value and then `base64` decode it.'

_RUN_CMD 'curl --silent \
  --header "X-Consul-Token: $CONSUL_HTTP_TOKEN" \
  --connect-to server.${CONSUL_DATACENTER}.${CONSUL_DOMAIN}:8443:consul-server-0:8443 \
  --cacert ~/assets/scenario/conf/secrets/consul-agent-ca.pem \
  https://server.${CONSUL_DATACENTER}.${CONSUL_DOMAIN}:8443/v1/kv/consul/configuration/db_port | \
  jq -r ".[].Value" | base64 --decode'

##  H2 -------------------------------------------------------------------------
md_h2 "Interact with Consul DNS"
# ------------------------------------------------------------------------------

md_log 'Consul also provides you with a fully featured DNS server that you can use to resolve the IPs for your services. 
By default, Consul DNS service is configured to listen on port `8600`.'


## [ux-diff] [cloud provider] UX differs across different Cloud providers

## Only works in Docker
_RUN_CMD -c 'dig @consul-server-0 -p 53 consul.service.consul'

