#!/usr/bin/env bash

# ++-----------------+
# || Functions       |
# ++-----------------+

# ++-----------------+
# || Variables       |
# ++-----------------+

username=${username:-$(whoami)}

export STEP_ASSETS="${SCENARIO_OUTPUT_FOLDER}conf/"


SCENARIO_NAME="Secure_02_service_intentions_l7"
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
md_h1 "Control service requests with application-aware intentions"
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
md_h2 "Prerequisites"
# ------------------------------------------------------------------------------

### H3 .........................................................................
md_h3 "Configure CLI to interact with Consul" 
# .............................................................................. 

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

### H3 .........................................................................
md_h3 "Check intentions for a Consul datacenter" 
# .............................................................................. 

md_log "After setting up the prerequisites, check the intentions configuration for your Consul datacenter."

#### TAB  ._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._
md_log "#### CLI == transform to TAB == " 
# ._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._

md_log "Use the consul intention command to check existing intentions."

_RUN_CMD -h "consul intention list"

#### TAB ._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._
md_log "#### API == transform to TAB == " 
# ._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._

md_log "Use the /connect/intentions endpoint to check existing intentions."

_RUN_CMD -o json -h 'curl --silent \
  --header "X-Consul-Token: $CONSUL_HTTP_TOKEN" \
  --connect-to server.${CONSUL_DATACENTER}.${CONSUL_DOMAIN}:8443:consul-server-0:8443 \
  --cacert ${CONSUL_CACERT} \
  https://server.${CONSUL_DATACENTER}.${CONSUL_DOMAIN}:8443/v1/connect/intentions | jq'


##  H2 -------------------------------------------------------------------------
md_h2 "Create ACL token for intentions management"
# ------------------------------------------------------------------------------

md_log "The script creates all the files in a destination folder. 
Export the path where you wish to create the configuration files for the scenario."

_RUN_CMD -h "export OUTPUT_FOLDER=${STEP_ASSETS}"
export OUTPUT_FOLDER="${STEP_ASSETS}"

md_log "Create a policy file for the ACL rules you want to grant."

_RUN_CMD -h 'tee ${OUTPUT_FOLDER}/acl-policy-intentions-hashicups-api-l7.hcl > /dev/null << EOF
# -----------------------------------------+
# acl-policy-intentions-hashicups-api-l7   |
# -----------------------------------------+

service_prefix "hashicups-" {
  policy = "read"
  intentions = "write"
}
EOF'

# log_err `cat ${OUTPUT_FOLDER}/acl-policy-intentions-hashicups.hcl`

md_log "Create the Consul policy."

_RUN_CMD -h 'consul acl policy create \
    -name "HashiCups-api-l7-intentions-policy" \
    -rules @${OUTPUT_FOLDER}/acl-policy-intentions-hashicups-api-l7.hcl'

md_log "Create a a token associated with the policy."

_RUN_CMD -h "consul acl token create \
    -description 'HashiCups API L7 Intentions Management token' \
    -policy-name HashiCups-api-l7-intentions-policy --format json > ${OUTPUT_FOLDER}secrets/acl-token-intentions-hashicups-api-l7.json"

md_log "To continue with the tutorial, using minimal permissions, export the first token as an environment variable."

_RUN_CMD -h 'export CONSUL_HTTP_TOKEN=`cat ${OUTPUT_FOLDER}secrets/acl-token-intentions-hashicups-api-l7.json | jq -r ".SecretID"`'
export CONSUL_HTTP_TOKEN=`cat ${OUTPUT_FOLDER}secrets/acl-token-intentions-hashicups-api-l7.json | jq -r ".SecretID"`

##  H2 -------------------------------------------------------------------------
md_h2 "Explore HashiCups API service endpoints"
# ------------------------------------------------------------------------------

_CONNECT_TO hashicups-api-0

md_log 'Check existing listening processes, the order of listeners might be different in your scenario.'

_RUN_CMD -r hashicups-api-0 -h 'netstat -natp | grep LISTEN'

md_log 'Run a query to the HashiCups API service from the API node.'

## ADD CURL TO API PURCHASE

### H3 .........................................................................
md_h3 "Explore the HashiCups API root path" 
# .............................................................................. 

md_log 'The default path, `/`, provides a number of information about the API service configuration.'

_RUN_CMD -r hashicups-db-0 -o html 'curl --silent http://localhost:8081/'

### H3 .........................................................................
md_h3 "Explore the HashiCups API /health path" 
# .............................................................................. 

md_log 'The API service also exposes a simple `/health` endpoint that provides a summary of the state of the service.'

_RUN_CMD -r hashicups-db-0 'curl --silent http://localhost:8081/health'

_EXIT_FROM hashicups-api-0

##  H2 -------------------------------------------------------------------------
md_h2 "Define and apply L7 intentions"
# ------------------------------------------------------------------------------

md_log 'The use of L7 intentions is only available for destination services using an HTTP-based protocol.'

#### TAB  ._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._
md_log "#### CLI == transform to TAB == " 
# ._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._

md_log 'In this case the destination service is `hashicups-api` and you can verify the configuration for it using the `consul config` command.'

_RUN_CMD -h "consul config read -kind service-defaults -name hashicups-api"

md_log 'The `404` message indicates that there is no configuration present for the `hashicups-api` service. The service can be regarded as a TCP-based service.'

#### TAB ._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._
md_log "#### API == transform to TAB == " 
# ._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._

md_log 'In this case the destination service is `hashicups-api` and you can verify the configuration for it using the `config/service-defaults` API endpoint.'

_RUN_CMD -h 'curl --silent \
  --header "X-Consul-Token: $CONSUL_HTTP_TOKEN" \
  --connect-to server.${CONSUL_DATACENTER}.${CONSUL_DOMAIN}:8443:consul-server-0:8443 \
  --cacert ${CONSUL_CACERT} \
  https://server.${CONSUL_DATACENTER}.${CONSUL_DOMAIN}:8443/v1/config/service-defaults/hashicups-api'

md_log 'In this scenario, the `hashicups-api` has no configuration applied to it. The service can be regarded as a TCP-based service.'

### H3 .........................................................................
md_h3 "Define service protocol for hashicups-api" 
# .............................................................................. 

md_log 'To apply L7 intentions to `hashicups-api` you will have to define it as an HTTP-based service first.'

md_log 'Define the output folder for the configuration file to be created.'

_RUN_CMD -h "export OUTPUT_FOLDER=${STEP_ASSETS}"
export OUTPUT_FOLDER="${STEP_ASSETS}"

#### TAB  ._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._
md_log "#### CLI == transform to TAB == " 
# ._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._

md_log 'Create the configuration file that defines the `Protocol` value for the service.'

_RUN_CMD -h 'tee ${OUTPUT_FOLDER}config-global-default-hashicups-api.hcl > /dev/null << EOF
Kind      = "service-defaults"
Name      = "hashicups-api"
Protocol  = "http"
EOF'

md_log 'Apply the configuration to your Consul datacenter.'

_RUN_CMD -h "consul config write ${OUTPUT_FOLDER}config-global-default-hashicups-api.hcl"

#### TAB ._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._
md_log "#### API == transform to TAB == " 
# ._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._

md_log 'Create the configuration file that defines the `Protocol` value for the service.'

_RUN_CMD -h 'tee ${OUTPUT_FOLDER}config-global-default-hashicups-api.json > /dev/null << EOF
{
  "Kind": "service-defaults",
  "Name": "hashicups-api",
  "Protocol": "http"
}
EOF'

md_log 'Apply the configuration to your Consul datacenter.'

_RUN_CMD -h 'curl --silent \
  --header "X-Consul-Token: $CONSUL_HTTP_TOKEN" \
  --connect-to server.${CONSUL_DATACENTER}.${CONSUL_DOMAIN}:8443:consul-server-0:8443 \
  --cacert ${CONSUL_CACERT} \
  --data @${OUTPUT_FOLDER}config-global-default-hashicups-api.json \
  --request PUT \
  https://server.${CONSUL_DATACENTER}.${CONSUL_DOMAIN}:8443/v1/config'

md_log 'Apply the configuration to your Consul datacenter.'

#### TAB  ._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._
md_log "#### CLI == transform to TAB == " 
# ._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._

_RUN_CMD -h "consul config read -kind service-defaults -name hashicups-api"

#### TAB ._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._
md_log "#### API == transform to TAB == " 
# ._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._

_RUN_CMD -o json -h 'curl --silent \
  --header "X-Consul-Token: $CONSUL_HTTP_TOKEN" \
  --connect-to server.${CONSUL_DATACENTER}.${CONSUL_DOMAIN}:8443:consul-server-0:8443 \
  --cacert ${CONSUL_CACERT} \
  https://server.${CONSUL_DATACENTER}.${CONSUL_DOMAIN}:8443/v1/config/service-defaults/hashicups-api | jq'


### H3 .........................................................................
md_h3 "Define L7 intentions for hashicups-api" 
# .............................................................................. 

md_log 'Once the API service is configured to be HTTP-based, it is possible to apply the L7 intention to it.'

#### TAB  ._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._
md_log "#### CLI == transform to TAB == " 
# ._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._

md_log 'First, create the configuration file to describe the intention.'

_RUN_CMD -h 'tee ${OUTPUT_FOLDER}config-intention-hashicups-api.hcl > /dev/null << EOF
Kind = "service-intentions"
Name = "hashicups-api"
Sources = [
  {
    Name = "hashicups-nginx"
    Permissions = [
      {
        Action = "allow"
        HTTP {
          PathExact = "/api"
        }
      }
    ]
  },
  {
    Name = "*"
    Permissions = [
      {
        Action = "deny"
        HTTP {
          PathExact = "/health"
          Methods   = ["GET"]
        }
      },
      {
        Action = "deny"
        HTTP {
          PathExact = "/"
          Methods   = ["GET"]
        }
      }
    ]
  },
  # NOTE: a default catch-all based on the default ACL policy will apply to
  # unmatched connections and requests. Typically this will be DENY.
]
EOF'

md_log 'Apply the configuration to your Consul datacenter.'

_RUN_CMD -h "consul config write ${OUTPUT_FOLDER}config-intention-hashicups-api.hcl"

#### TAB ._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._
md_log "#### API == transform to TAB == " 
# ._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._

md_log 'Create the configuration file to describe the intention.'

_RUN_CMD -h 'tee ${OUTPUT_FOLDER}config-intention-hashicups-api.json > /dev/null << EOF
{
  "Kind": "service-intentions",
  "Name": "hashicups-api",
  "Sources": [
    {
      "Name": "hashicups-nginx",
      "Permissions": [
        {
          "Action": "allow",
          "HTTP": {
            "PathExact": "/api"
          }
        }
      ]
    },
    {
      "Name": "*",
      "Permissions": [
        {
          "Action": "deny",
          "HTTP": {
            "PathExact": "/",
            "Methods": [
              "GET"
            ]
          }
        },
        {
          "Action": "deny",
          "HTTP": {
            "PathExact": "/health",
            "Methods": [
              "GET"
            ]
          }
        }
      ]
    }
  ]
}
EOF'

md_log 'Apply the configuration to your Consul datacenter.'

_RUN_CMD -h 'curl --silent \
  --header "X-Consul-Token: $CONSUL_HTTP_TOKEN" \
  --connect-to server.${CONSUL_DATACENTER}.${CONSUL_DOMAIN}:8443:consul-server-0:8443 \
  --cacert ${CONSUL_CACERT} \
  --data @${OUTPUT_FOLDER}config-intention-hashicups-api.json \
  --request PUT \
  https://server.${CONSUL_DATACENTER}.${CONSUL_DOMAIN}:8443/v1/config'


### H3 .........................................................................
md_h3 "Check intentions in your Consul datacenter" 
# .............................................................................. 

md_log "After applying the desired intention, check the new intentions configuration for your Consul datacenter."

#### TAB  ._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._
md_log "#### CLI == transform to TAB == " 
# ._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._

md_log "Use the consul intention command to check existing intentions."

_RUN_CMD "consul intention list"

md_log "To get more details over the specific intentions in place for hashicups-api, use the consul config command."

_RUN_CMD -o plaintext "consul config read -kind service-intentions -name hashicups-api"

#### TAB ._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._
md_log "#### API == transform to TAB == " 
# ._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._

md_log "Use the /connect/intentions endpoint to check existing intentions."

_RUN_CMD -o json 'curl --silent \
  --header "X-Consul-Token: $CONSUL_HTTP_TOKEN" \
  --connect-to server.${CONSUL_DATACENTER}.${CONSUL_DOMAIN}:8443:consul-server-0:8443 \
  --cacert ${CONSUL_CACERT} \
  https://server.${CONSUL_DATACENTER}.${CONSUL_DOMAIN}:8443/v1/connect/intentions | jq'


##  H2 -------------------------------------------------------------------------
md_h2 "Verify connections are now secured"
# ------------------------------------------------------------------------------

### H3 .........................................................................
md_h3 "Test service to service connection" 
# .............................................................................. 

_CONNECT_TO hashicups-nginx-0

md_log 'Verify the connection to the API service from the NGINX node.'

_RUN_CMD -o json -r hashicups-nginx-0 'curl --silent "http://localhost:8081/api" \
      -H "Accept-Encoding: gzip, deflate, br" \
      -H "Content-Type: application/json" \
      -H "Accept: application/json" \
      -H "Connection: keep-alive" \
      -H "DNT: 1" \
      -H "Origin: http://localhost:8081" \
      --data-binary '\''{"query":"mutation{ pay(details:{ name: \"nic\", type: \"mastercard\", number: \"1234123-0123123\", expiry:\"10/02\",    cv2: 1231, amount: 12.23 }){id, card_plaintext, card_ciphertext, message } }"}'\'' --compressed | jq'

md_log 'Test if the `/` endpoint is reachable.'

_RUN_CMD -o plaintext -r hashicups-nginx-0 'curl --silent http://localhost:8081/'

md_log 'Test if the /health endpoint is reachable.'

_RUN_CMD -o plaintext -r hashicups-nginx-0 'curl --silent http://localhost:8081/health'

_EXIT_FROM hashicups-nginx-0





