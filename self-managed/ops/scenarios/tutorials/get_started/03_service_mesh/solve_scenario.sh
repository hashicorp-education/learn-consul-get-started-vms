#!/usr/bin/env bash

# ++-----------------+
# || Functions       |
# ++-----------------+

# ++-----------------+
# || Variables       |
# ++-----------------+

username=${username:-$(whoami)}

export STEP_ASSETS="${SCENARIO_OUTPUT_FOLDER}conf/"


SCENARIO_NAME="GS_04_service_mesh_access"
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
md_h1 "Access services in your service mesh"
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
md_h2 "Add API gateway node to Consul datacenter"
# ------------------------------------------------------------------------------

md_log "Consul API Gateway uses the same components as the rest of the service 
mesh client nodes to join the Consul datacenter. This means that you need a 
Consul agent running and an Envoy proxy instance to act as a proxy for the 
services you want to expose outside your service mesh."

### H3 .........................................................................
md_h3 "Generate Consul configuration for API gateway" 
# ..............................................................................  

md_log "Consul API Gateway uses the same components as the rest of the service 
mesh client nodes to join the Consul datacenter. This means that you need a 
Consul agent running and an Envoy proxy instance to act as a proxy for the 
services you want to expose outside your service mesh."

for i in `seq ${api_gw_NUMBER}`; do

    NODE_NAME="gateway-api-$((i-1))"

    if [ "${api_gw_NUMBER}" -gt 1 ]; then
      #### H4 ._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._
      md_log "#### Generate configuration for ${NODE_NAME}" 
      # ._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._
    fi

    md_log 'First, define the Consul node name.'

    _RUN_CMD 'export NODE_NAME="'${NODE_NAME}'"'
    export NODE_NAME

    md_log 'Then, generate the Consul configuration for the API Gateway node.'

    export COLORED_OUTPUT=false
    export PREPEND_DATE=false

    ## [cmd] [script] generate_consul_client_config.sh
    _RUN_CMD -c "~/ops/scenarios/00_base_scenario_files/supporting_scripts/generate_consul_client_config.sh"

    md_log 'To complete Consul agent configuration, you need to setup tokens for 
the client. For this tutorial, you are using the bootstrap token. We recommend 
using more restrictive tokens for your Consul client agents in production.'

    _RUN_CMD 'tee ${OUTPUT_FOLDER}${NODE_NAME}/agent-acl-tokens.hcl > /dev/null << EOF
acl {
  tokens {
    agent  = "${CONSUL_HTTP_TOKEN}"
    default  = "${CONSUL_HTTP_TOKEN}"
    config_file_service_registration = "${CONSUL_HTTP_TOKEN}"
  }
}
EOF
'
  
  md_log 'Once you have generated your configuration files, your directory should look like the following:'

  _RUN_CMD -c 'tree ${OUTPUT_FOLDER}'${NODE_NAME}

  md_log 'The scripts generated multiple configuration files to separate the configuration so it is easier to read and tune them for your environment. 
The following are the generated files and a description of what they do:
1. The `agent-acl-tokens.hcl` file contains tokens for the Consul agent.
1. The `agent-gossip-encryption.hcl` file configures gossip encryption.
1. The `consul-agent-ca.pem` file is the public certificate for Consul CA.
1. The `consul.hcl` file contains node specific configuration and it is needed, with this specific name, if you want to configure Consul as a systemd daemon.'

  md_log "Visit the [agent configuration](/consul/docs/agent/config/config-files) 
documentation to interpret the files or to modify them when applying them to your environment."

md_log "After the script generates the client configuration, you will copy these 
files into the API gateway node."

md_log 'First, configure the Consul configuration directory.'

_RUN_CMD -h 'export CONSUL_REMOTE_CONFIG_DIR=/etc/consul.d/'
export CONSUL_REMOTE_CONFIG_DIR=/etc/consul.d/

md_log 'Then, use `rsync` to copy the service configuration file into the remote node.'

_RUN_CMD 'rsync -av \
 	-e "ssh -i ~/certs/id_rsa" \
 	${OUTPUT_FOLDER}'${NODE_NAME}''/' \
 	'${NODE_NAME}':${CONSUL_REMOTE_CONFIG_DIR}'

done

### H3 .........................................................................
md_h3 "Start Consul on API GW" 
# ..............................................................................  
  
for i in `seq ${api_gw_NUMBER}`; do

    NODE_NAME="gateway-api-$((i-1))"

    if [ "${api_gw_NUMBER}" -gt 1 ]; then
      #### H4 ._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._
      md_log "#### Start Consul for ${NODE_NAME}" 
      # ._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._
    fi

  md_log "Login to the API Gateway VM from the bastion host."

  _CONNECT_TO ${NODE_NAME}

  md_log "Define the Consul configuration and data directories."

  _RUN_CMD -h 'export CONSUL_CONFIG_DIR=/etc/consul.d/ \
export CONSUL_DATA_DIR=/opt/consul/'
  export CONSUL_CONFIG_DIR=/etc/consul.d/
  export CONSUL_DATA_DIR=/opt/consul/

  md_log "Ensure your user has write permission to the Consul data directory."

  _RUN_CMD -r ${NODE_NAME} -h -e "CONSUL_DATA_DIR" 'sudo chmod g+w ${CONSUL_DATA_DIR}'

  md_log 'Finally, start the Consul server process.'

  _RUN_CMD -r ${NODE_NAME} -h -e "CONSUL_CONFIG_DIR" 'consul agent -config-dir=${CONSUL_CONFIG_DIR} > /tmp/consul-client.log 2>&1 &'

  sleep 5

  md_log 'The process is started in background to not lock the terminal. Consul server log can be accessed in the `/tmp/consul-client.log` file.'

  md_log 'Verify Consul API Gateway successfully joined the datacenter using the `consul members` command.'

  _RUN_CMD -r ${NODE_NAME} 'consul members'

  _EXIT_FROM ${NODE_NAME}

done


##  H2 -------------------------------------------------------------------------
md_h2 "Generate API Gateway rules"
# ------------------------------------------------------------------------------

md_log " Now that the Consul agent for the API Gateway successfully joined the 
datacenter, it is time to create the configuration for the Consul Data Plane.

Consul API Gateway is configured using Consul global configuration entries so 
you can configure it from a remote node. For this scenario, you will use the 
bastion host VM to generate, store, and apply the configuration.

To configure a Consul API Gateway you need two configurations:

1. A TLS certificate used by the API Gateway to secure connections to the mesh services.
1. An API Gateway configuration entry, defining the listeners that the gateway exposes externally and the certificates associated with them.
"

### H3 .........................................................................
md_h3 "Generate API Gateway certificate" 
# ..............................................................................  

md_log "You can create the certificate using an internal or public CA so your 
services can be compliant with your internal standards."

md_log 'For this tutorial, you will use `openssl` to generate a valid certificate for the HashiCups application.'

md_log "Define the certificate common name."

_RUN_CMD -h 'export COMMON_NAME="hashicups.hashicorp.com"'
export COMMON_NAME="hashicups.hashicorp.com"

md_log 'Create a configuration file for `openssl`.'

_RUN_CMD -h 'tee ${OUTPUT_FOLDER}gateway-api-ca-config.cnf > /dev/null << EOF
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
EOF'

md_log 'Generate a private key.'

_RUN_CMD -h 'openssl genrsa -out ${OUTPUT_FOLDER}gateway-api-cert.key  4096 2>/dev/null'

md_log 'Create a certificate signing request.'

_RUN_CMD -h 'openssl req -new \
  -key ${OUTPUT_FOLDER}gateway-api-cert.key \
  -out ${OUTPUT_FOLDER}gateway-api-csr.csr \
  -config ${OUTPUT_FOLDER}gateway-api-ca-config.cnf 2>/dev/null'

md_log 'Finally, sign the certificate and save it to a `crt` file.'

_RUN_CMD -h 'openssl x509 -req -days 3650 \
  -in ${OUTPUT_FOLDER}gateway-api-csr.csr \
  -signkey ${OUTPUT_FOLDER}gateway-api-cert.key \
  -out ${OUTPUT_FOLDER}gateway-api-cert.crt 2>/dev/null'


#### TAB ._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._
md_log "#### Filesystem certificate == transform to TAB == " 
# ._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._

md_log "The file system certificate is the most secure approach to provide a TLS 
certificate to Consul API Gateway on VMs because it references a local filepath 
instead of including sensitive information in the configuration entry itself. 
File system certificates also include a file system watch that implements 
certificate and key changes without restarting the gateway."

md_log 'Populate the configuration file with deisred path for the certificate and key.'

_RUN_CMD -h 'tee ${OUTPUT_FOLDER}config-gateway-api-fs-certificate.hcl > /dev/null << EOF
Kind = "file-system-certificate"
Name = "api-gw-certificate"

Certificate = "/etc/consul.d/gateway-api-cert.crt"

PrivateKey = "/etc/consul.d/gateway-api-cert.key"
EOF'

for i in `seq ${api_gw_NUMBER}`; do

    NODE_NAME="gateway-api-$((i-1))"

    if [ "${api_gw_NUMBER}" -gt 1 ]; then
      #### H4 ._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._
      md_log "#### Copy certificates on ${NODE_NAME}" 
      # ._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._
    fi

    md_log "Copy the certificate to the remote node."

    _RUN_CMD 'rsync -av \
-e "ssh -i ~/certs/id_rsa" \
${OUTPUT_FOLDER}gateway-api-cert* \
'${NODE_NAME}':/etc/consul.d/'

done

### H3 .........................................................................
md_h3 "Generate API Gateway configuration" 
# ..............................................................................  

md_log "The following API Gateway configuration entry includes listener 
configuration and a reference to the TLS certificate that the gateway exposes."

_RUN_CMD -h 'tee ${OUTPUT_FOLDER}config-gateway-api-fs.hcl > /dev/null << EOF
Kind = "api-gateway"
Name = "gateway-api"

// Each listener configures a port which can be used to access the Consul cluster
Listeners = [
    {
        Port = 8443
        Name = "api-gw-listener"
        Protocol = "http"
        TLS = {
            Certificates = [
                {
                    Kind = "file-system-certificate"
                    Name = "api-gw-certificate"
                }
            ]
        }
    }
]
EOF'

### H3 .........................................................................
md_h3 "Apply the configuration to Consul datacenter" 
# ..............................................................................  

md_log 'You can now apply the configuration to Consul datacenter.'

_RUN_CMD 'consul config write ${OUTPUT_FOLDER}config-gateway-api-fs.hcl; \
consul config write ${OUTPUT_FOLDER}config-gateway-api-fs-certificate.hcl'

## Removing the configuration to avoid conflicts
consul config delete -kind api-gateway -name api-gw-listener
consul config delete -kind file-system-certificate -name api-gw-certificate

#### TAB ._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._
md_log "#### Inline certificate == transform to TAB == " 
# ._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._

md_log 'You can now generate the certificate configuration using the `.key` and `.crt` files.'

md_log 'First populate two environment variables with the files content.'

_RUN_CMD -h 'export API_GW_KEY=`cat ${OUTPUT_FOLDER}gateway-api-cert.key`; \
export API_GW_CERT=`cat ${OUTPUT_FOLDER}gateway-api-cert.crt`'
export API_GW_KEY=`cat ${OUTPUT_FOLDER}gateway-api-cert.key`
export API_GW_CERT=`cat ${OUTPUT_FOLDER}gateway-api-cert.crt`

md_log 'Then populate the configuration file with the inline certificate and key.'

_RUN_CMD -h 'tee ${OUTPUT_FOLDER}config-gateway-api-inline-certificate.hcl > /dev/null << EOF
Kind = "inline-certificate"
Name = "api-gw-certificate"

Certificate = <<EOT
${API_GW_CERT}
EOT

PrivateKey = <<EOT
${API_GW_KEY}
EOT
EOF'

### H3 .........................................................................
md_h3 "Generate API Gateway configuration" 
# ..............................................................................  

md_log "The following API Gateway configuration entry includes listener 
configuration and a reference to the TLS certificate that the gateway exposes."

_RUN_CMD -h 'tee ${OUTPUT_FOLDER}config-gateway-api-inline.hcl > /dev/null << EOF
Kind = "api-gateway"
Name = "gateway-api"

// Each listener configures a port which can be used to access the Consul cluster
Listeners = [
    {
        Port = 8443
        Name = "api-gw-listener"
        Protocol = "http"
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
EOF'

### H3 .........................................................................
md_h3 "Apply the configuration to Consul datacenter" 
# ..............................................................................  

md_log 'You can now apply the configuration to Consul datacenter.'

_RUN_CMD 'consul config write ${OUTPUT_FOLDER}config-gateway-api-inline.hcl; \
consul config write ${OUTPUT_FOLDER}config-gateway-api-inline-certificate.hcl'

##  H2 -------------------------------------------------------------------------
md_h2 "Start API gateway"
# ------------------------------------------------------------------------------

md_log 'Now that you have configured API Gateway, you can start the Envoy process that will serve external requests.'

for i in `seq ${api_gw_NUMBER}`; do

    NODE_NAME="gateway-api-$((i-1))"

    if [ "${api_gw_NUMBER}" -gt 1 ]; then
      #### H4 ._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._
      md_log "#### Start Envoy for ${NODE_NAME}" 
      # ._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._
    fi

  md_log "Login to the API Gateway VM from the bastion host."

  _CONNECT_TO ${NODE_NAME}

  md_log "Then, configure the token for the Envoy process."

  _RUN_CMD -h 'export CONSUL_AGENT_TOKEN=`cat /etc/consul.d/agent-acl-tokens.hcl | grep agent | awk '\''{print $3}'\''| sed '\''s/"//g'\''`'
  export CONSUL_AGENT_TOKEN=`cat ${OUTPUT_FOLDER}${NODE_NAME}/agent-acl-tokens.hcl | grep agent | awk '{print $3}'| sed 's/"//g'`

  _RUN_CMD -r ${NODE_NAME} -e CONSUL_AGENT_TOKEN '/usr/bin/consul connect envoy \
  -gateway api \
  -register \
  -service gateway-api \
  -token=${CONSUL_AGENT_TOKEN} \
  -envoy-binary /usr/bin/envoy > /tmp/api-gw-proxy.log 2>&1 &'

  _EXIT_FROM ${NODE_NAME}

done

##  H2 -------------------------------------------------------------------------
md_h2 "Apply route"
# ------------------------------------------------------------------------------

md_log "At this point, Consul API Gateway is ready to serve requests but no route 
is configured to expose services in the mesh externally."

md_log 'For this tutorial, you will expose the HashiCups application using the `hashicups-nginx` service as entry point.'

### H3 .........................................................................
md_h3 "Generate API Gateway route" 
# ..............................................................................  

md_log 'From the bastion host, create a route to redirect ingress traffic to the `hashicups-nginx` service.'

_RUN_CMD -h 'tee ${OUTPUT_FOLDER}config-gateway-api-http-route.hcl > /dev/null << EOF
Kind = "http-route"
Name = "hashicups-http-route"

// Rules define how requests will be routed
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
EOF'

md_log 'Then, apply the configuration to Consul.'

_RUN_CMD -c 'consul config write ${OUTPUT_FOLDER}config-gateway-api-http-route.hcl'

##  H2 -------------------------------------------------------------------------
md_h2 "Create intention for service access"
# ------------------------------------------------------------------------------

md_log 'To allow access to your NGINX service that serves the HashiCups application, create an intention that allows traffic from `gateway-api` service to `hashicups-nginx` service.'

md_log 'First make sure the folder exists.'

_RUN_CMD -h 'mkdir -p ${OUTPUT_FOLDER}global'

md_log 'Then create the intention configuration file.'

_RUN_CMD -h 'tee ${OUTPUT_FOLDER}global/intention-nginx.hcl > /dev/null << EOF
Kind = "service-intentions"
Name = "hashicups-nginx"
Sources = [
  {
    Name   = "gateway-api"
    Action = "allow"
  }
]
EOF'

md_log 'After creating the configuration file for the intention, apply it.'

_RUN_CMD -c 'consul config write ${OUTPUT_FOLDER}global/intention-nginx.hcl '

##  H2 -------------------------------------------------------------------------
md_h2 "Verify HashiCups is now reachable using API Gateway"
# ------------------------------------------------------------------------------

md_log "After applying the route, you are able to access the HashiCups 
application using the Consul API gateway address."

md_log "First, retrieve the API Gateway address. For this scenario, you can get 
the API Gateway public IP directly from the bastion host."

# ## [ux-diff] [cloud provider] UX differs across different Cloud providers
# if [ "${SCENARIO_CLOUD_PROVIDER}" == "docker" ]; then

#   _RUN_CMD 'echo "https://`cat /etc/hosts | grep gateway-api-public | awk '{print $1}'`:8443"'

# elif [ "${SCENARIO_CLOUD_PROVIDER}" == "aws" ]; then

#   _RUN_CMD 'echo "https://`cat /etc/hosts | grep gateway-api-public | awk '{print $1}'`:8443"'

# elif [ "${SCENARIO_CLOUD_PROVIDER}" == "azure" ]; then

#   _RUN_CMD 'echo "https://`cat /etc/hosts | grep gateway-api-public | awk '{print $1}'`:8443"'

# fi

# _RUN_CMD 'echo "https://`cat /etc/hosts | grep gateway-api-public | awk '{print $1}'`:8443"'

# md_log 'Then, open the address in a browser.'

##  H2 -------------------------------------------------------------------------
md_h2 "Remove direct access to hashicups-nginx"
# ------------------------------------------------------------------------------

md_log "At this point, the HashiCups application is still accessible using the 
old, insecure, endpoint."

md_log 'The last step is to ensure `hashicups-nginx` service will only serve local requests.'

NODES_ARRAY=( "hashicups-nginx" )

for node in "${NODES_ARRAY[@]}"; do

  NUM="${node/-/_}""_NUMBER"
  
  for i in `seq ${!NUM}`; do

    export NODE_NAME="${node}-$((i-1))"

    if [ "${!NUM}" -gt 1 ]; then
      #### H4 ._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._
      md_log "#### Restart service on ${NODE_NAME}" 
      # ._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._._
    fi

    _RUN_CMD  'ssh -i ~/certs/id_rsa '${NODE_NAME}' "bash -c \
    '\''bash ./start_service.sh start --local'\''"'

  done
done

md_log "The insecure endpoint is not available anymore. You can only access your 
application securely through the Consul API Gateway."

