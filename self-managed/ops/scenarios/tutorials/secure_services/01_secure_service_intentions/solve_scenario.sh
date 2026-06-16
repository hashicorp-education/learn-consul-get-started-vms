#!/usr/bin/env bash

# ++-----------------+
# || Functions       |
# ++-----------------+

# ++-----------------+
# || Variables       |
# ++-----------------+

username=${username:-$(whoami)}

export STEP_ASSETS="${SCENARIO_OUTPUT_FOLDER}conf/"


SCENARIO_NAME="Secure_01_service_intentions"
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
md_h1 "Control traffic communication between services with intentions"
# ==============================================================================

md_log "This is a solution runbook for the scenario deployed."

##  H2 -------------------------------------------------------------------------
md_h2 "Prerequisites"
# ------------------------------------------------------------------------------

### H3 .........................................................................
md_h3 "Login into the bastion host VM" 
# ..............................................................................  

md_log "Log into the bastion host using ssh"

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

# log_err "TOKEN $CONSUL_HTTP_TOKEN"

md_log "The script creates all the files in a destination folder. 
Export the path where you wish to create the configuration files for the scenario."


##  H2 -------------------------------------------------------------------------
md_h2 "Create ACL token for intentions management"
# ------------------------------------------------------------------------------

md_log "The script creates all the files in a destination folder. 
Export the path where you wish to create the configuration files for the scenario."

_RUN_CMD -h "export OUTPUT_FOLDER=${STEP_ASSETS}"
export OUTPUT_FOLDER="${STEP_ASSETS}"

md_log "Create a policy file for the ACL rules you want to grant."

_RUN_CMD -h 'tee ${OUTPUT_FOLDER}/acl-policy-intentions-hashicups.hcl > /dev/null << EOF
# --------------------------------------+
# acl-policy-intentions-hashicups.hcl   |
# --------------------------------------+

service_prefix "hashicups-" {
  policy = "read"
  intentions = "write"
}
EOF'

# log_err `cat ${OUTPUT_FOLDER}/acl-policy-intentions-hashicups.hcl`

md_log "Create the Consul policy."

_RUN_CMD -h 'consul acl policy create \
    -name "HashiCups-intentions-policy" \
    -rules @${OUTPUT_FOLDER}/acl-policy-intentions-hashicups.hcl'

md_log "Create a a token associated with the policy."

_RUN_CMD -h "consul acl token create \
    -description 'HashiCups Intentions Management token' \
    -policy-name HashiCups-intentions-policy --format json > ${OUTPUT_FOLDER}secrets/acl-token-intentions-hashicups.json"

### H3 .........................................................................
md_h3 "Extended permissions" 
# .............................................................................. 

md_log "Create another policy that grants intentions:write for all services."

_RUN_CMD -h 'tee ${OUTPUT_FOLDER}/acl-policy-intentions-all.hcl > /dev/null << EOF
# --------------------------------------+
# acl-policy-intentions-all.hcl   |
# --------------------------------------+

service_prefix "" {
  policy = "read"
  intentions = "write"
}
EOF'

md_log "With the new rules file, create the policy."

_RUN_CMD -h "consul acl policy create \
    -name "all-intentions-policy" \
    -rules @${OUTPUT_FOLDER}/acl-policy-intentions-all.hcl"

md_log "Create a token associated with the policy."

_RUN_CMD -h "consul acl token create \
    -description 'All Intentions Management token' \
    -policy-name all-intentions-policy --format json > ${OUTPUT_FOLDER}secrets/acl-token-intentions-all.json"

md_log "To continue with the tutorial, using minimal permissions, export the first token as an environment variable."

_RUN_CMD -h 'export CONSUL_HTTP_TOKEN=`cat ${OUTPUT_FOLDER}secrets/acl-token-intentions-hashicups.json | jq -r ".SecretID"`'
export CONSUL_HTTP_TOKEN=`cat ${OUTPUT_FOLDER}secrets/acl-token-intentions-hashicups.json | jq -r ".SecretID"`

##  H2 -------------------------------------------------------------------------
md_h2 "Check intentions for a Consul datacenter"
# ------------------------------------------------------------------------------

md_log "Check existing intentions in your Consul datacenter."

#### TAB  ._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._
md_log "#### CLI == transform to TAB == " 
# ._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._

md_log "Use the consul intention command to check existing intentions."

_RUN_CMD -h "consul intention list"

#### TAB ._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._
md_log "#### API == transform to TAB == " 
# ._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._

md_log "Use the /connect/intentions endpoint to check existing intentions."

_RUN_CMD -h 'curl --silent \
  --header "X-Consul-Token: $CONSUL_HTTP_TOKEN" \
  --connect-to server.${CONSUL_DATACENTER}.${CONSUL_DOMAIN}:8443:consul-server-0:8443 \
  --cacert ${CONSUL_CACERT} \
  https://server.${CONSUL_DATACENTER}.${CONSUL_DOMAIN}:8443/v1/connect/intentions | jq'

### H3 .........................................................................
md_h3 "Check HashiCups UI" 
# ..............................................................................  

md_log "Retrieve the API Gateway public IP from the bastion host."

# _RUN_CMD -h "echo \"https://`cat /etc/hosts | grep gateway-api-public | awk '{print $1}'`:8443\""

##  H2 -------------------------------------------------------------------------
md_h2 "Enable a new service-to-service communication"
# ------------------------------------------------------------------------------

### H3 .........................................................................
md_h3 "Check initial status" 
# .............................................................................. 

_CONNECT_TO hashicups-api-0

md_log 'Check existing listening processes, the order of listeners might be different in your scenario.'

_RUN_CMD -r hashicups-api-0 -h 'netstat -natp | grep LISTEN'

_EXIT_FROM hashicups-api-0

### H3 .........................................................................
md_h3 "Add a new upstream to a service definition" 
# ..............................................................................

_CONNECT_TO hashicups-db-0

md_log 'Check existing listening processes, the order of listeners might be different in your scenario.'

_RUN_CMD -r hashicups-db-0 -h 'netstat -natp | grep LISTEN'

md_log 'Populate `CONSUL_HTTP_TOKEN` variable using the token used by the Consul client agent to register the service.'

_RUN_CMD -h 'export CONSUL_HTTP_TOKEN=`cat /etc/consul.d/svc.hcl | grep token | awk '{print $3}' | tr -d \"`'
export CONSUL_HTTP_TOKEN=`cat ${OUTPUT_FOLDER}hashicups-db-0/svc/service_discovery/svc-hashicups-db.hcl | grep token | awk '{print $3}' | tr -d \"`

md_log 'Generate the new service definition file to include the upstream definition.'

_RUN_CMD -r hashicups-db-0 -h 'tee /etc/consul.d/svc.hcl > /dev/null << EOF
## svc-hashicups-db.hcl
service {
  name = "hashicups-db"
  id = "hashicups-db-0"
  port = 5432
  token = "${CONSUL_HTTP_TOKEN}"
  connect {
    sidecar_service {
      proxy {
        upstreams = [
          {
            destination_name = "hashicups-api"
            local_bind_port = 8081
          }
        ]
      }
    }
  }
  check
  {
    id =  "check-hashicups-db",
    name = "hashicups-db status check",
    service_id = "hashicups-db-0",
    tcp  = "localhost:5432",
    interval = "5s",
    timeout = "5s"
  }
}
EOF'

md_log 'Update the token to get permission to reload Consul.'

_RUN_CMD -h 'export CONSUL_HTTP_TOKEN=`cat /etc/consul.d/agent-acl-tokens.hcl | grep agent | awk '{print $3}' | tr -d \"`'
export CONSUL_HTTP_TOKEN=`cat ${OUTPUT_FOLDER}hashicups-db-0/agent-acl-tokens.hcl | grep agent | awk '{print $3}' | tr -d \"`

md_log 'Reload Consul to apply the new service configuration.'

_RUN_CMD -r hashicups-db-0 -e "CONSUL_HTTP_TOKEN" -h "consul reload"

md_log 'After the Consul agent reloaded the configuration, it will automatically update the Envoy sidecar proxy configuration to include the new upstream on the local node.'

_RUN_CMD -r hashicups-db-0 -h 'netstat -natp | grep LISTEN'


### H3 .........................................................................
md_h3 "Check service connection" 
# ..............................................................................

md_log 'Verify you can now connect to the API service from the Database node.'

_RUN_CMD -r hashicups-db-0 'curl --silent http://localhost:8081/health'

_EXIT_FROM hashicups-db-0

##  H2 -------------------------------------------------------------------------
md_h2 "Tune intentions for your environment"
# ------------------------------------------------------------------------------

##  H2 -------------------------------------------------------------------------
md_h2 "Define and apply intentions"
# ------------------------------------------------------------------------------

md_log 'Use the provided script to generate service intentions.'

_RUN_CMD -h "export OUTPUT_FOLDER=${STEP_ASSETS}"

export COLORED_OUTPUT=false
export PREPEND_DATE=false

## [cmd] [script] generate_global_config_hashicups.sh
_RUN_CMD -c "~/ops/scenarios/00_base_scenario_files/supporting_scripts/generate_global_config_hashicups.sh"

md_log 'Check the files generated by the script.'

_RUN_CMD -c 'tree ${OUTPUT_FOLDER}/global'

### H3 .........................................................................
md_h3 "Apply specific intentions" 
# ..............................................................................

md_log 'Finally apply the intentions to your Consul datacenter.'

source ~/assets/scenario/env-scenario.env
source ~/assets/scenario/env-consul.env

#### TAB ._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._
md_log "#### CLI == transform to TAB == " 
# ._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._

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
md_h3 "Remove default intention" 
# ..............................................................................

md_log 'Remove the allow-all intention without affecting the application uptime.'

#### TAB ._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._
md_log "#### CLI == transform to TAB == " 
# ._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._

md_log 'Use `consul config delete` to remove the intention.'

_RUN_CMD -o plaintext -c 'consul config delete -kind service-intentions -name "*"'

md_log 'If the token you are using does not include necessary permissions to manipulate intentions for all services, the request is expected to fail with a 403 error.'

_RUN_CMD -h 'export CONSUL_HTTP_TOKEN=`cat ${OUTPUT_FOLDER}secrets/acl-token-intentions-all.json | jq -r ".SecretID"`'
export CONSUL_HTTP_TOKEN=`cat ${OUTPUT_FOLDER}secrets/acl-token-intentions-all.json | jq -r ".SecretID"`

md_log 'The new attempt should be successful.'

_RUN_CMD -c 'consul config delete -kind service-intentions -name "*"'

md_log 'Once you completed the intention deletion, you should revert back to a less privileged token.'

_RUN_CMD -h 'export CONSUL_HTTP_TOKEN=`cat ${OUTPUT_FOLDER}secrets/acl-token-intentions-hashicups.json | jq -r ".SecretID"`'
export CONSUL_HTTP_TOKEN=`cat ${OUTPUT_FOLDER}secrets/acl-token-intentions-hashicups.json | jq -r ".SecretID"`

#### TAB ._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._
md_log "#### API == transform to TAB == " 
# ._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._

md_log ''

### H3 .........................................................................
md_h3 "Check intentions in your Consul datacenter" 
# ..............................................................................

#### TAB ._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._
md_log "#### CLI == transform to TAB == " 
# ._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._

md_log 'Use the `consul intention` command to check existing intentions.'

_RUN_CMD -c '_RUN_CMD -c 'consul config delete -kind service-intentions -name "*"''

#### TAB ._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._
md_log "#### API == transform to TAB == " 
# ._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._

md_log 'Use the /connect/intentions endpoint to check existing intentions.'

_RUN_CMD -o json -h 'curl --silent \
  --header "X-Consul-Token: $CONSUL_HTTP_TOKEN" \
  --connect-to server.${CONSUL_DATACENTER}.${CONSUL_DOMAIN}:8443:consul-server-0:8443 \
  --cacert ${CONSUL_CACERT} \
  https://server.${CONSUL_DATACENTER}.${CONSUL_DOMAIN}:8443/v1/connect/intentions | jq'

##  H2 -------------------------------------------------------------------------
md_h2 "Verify connections are now secured"
# ------------------------------------------------------------------------------

### H3 .........................................................................
md_h3 "Check HashiCups UI" 
# ..............................................................................


### H3 .........................................................................
md_h3 "Test service to service connection" 
# ..............................................................................

_CONNECT_TO hashicups-db-0

md_log "Verify the connection to the API service from the Database node."

_RUN_CMD -r hashicups-db-0 'curl --silent http://localhost:8081/health'

_EXIT_FROM hashicups-db-0

