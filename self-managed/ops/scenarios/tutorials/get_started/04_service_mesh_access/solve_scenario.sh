#!/usr/bin/env bash

# ++-----------------+
# || Functions       |
# ++-----------------+

# ++-----------------+
# || Variables       |
# ++-----------------+

username=${username:-$(whoami)}

export STEP_ASSETS="${SCENARIO_OUTPUT_FOLDER}conf/"


SCENARIO_NAME="GS_05_monitoring"
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
md_h1 "Observe Consul service mesh traffic"
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

### H3 .........................................................................
md_h3 "Verify Grafana agent binary" 
# ..............................................................................  

md_log 'Check on each of the Consul nodes (**Consul server**, **NGINX**, **Frontend**, **API**, and **Database**) to verify Grafana agent is installed.'

_RUN_CMD -r consul-server-0 -c 'grafana-agent --version'


##  H2 -------------------------------------------------------------------------
md_h2 "Configure Grafana Agent"
# ------------------------------------------------------------------------------

md_log 'You can configure Grafana Agent to collect several kinds of data from your VM. In this tutorial, you will use configurations for:

- [`metrics`](https://grafana.com/docs/agent/latest/configuration/metrics-config/) block, to define a collection of Prometheus-compatible scrape configs to be written in Mimir.
- [`logs`](https://grafana.com/docs/agent/latest/configuration/logs-config/) block, to configure how the Agent collects logs and sends them to a Loki push API endpoint.'

### H3 .........................................................................
md_h3 "Generate configuration for Grafana Agent" 
# ..............................................................................  

md_log "This tutorial and interactive lab environment uses scripts in the 
tutorial's [GitHub repository](https://github.com/hashicorp-education/learn-consul-get-started-vms) 
to generate the Consul configuration files for your client agents."

md_log 'The script requires a few parameters to work correctly:

- an `OUTPUT_FOLDER` to place the files generated
-a `PROMETHEUS_URI` to push metrics to. In this scenario we configured Grafana Mimir for this task listening on the bastion host.
- a `LOKI_URI` to push logs to. In this scenario we configured Grafana Loki for this task listening on the bastion host.'

_RUN_CMD -h 'export OUTPUT_FOLDER='${STEP_ASSETS}'; \
export PROMETHEUS_URI=`getent hosts mimir | awk '\''{print $1}'\''`; \
export LOKI_URI=`getent hosts loki | awk '\''{print $1}'\'''

export OUTPUT_FOLDER=${STEP_ASSETS}
export PROMETHEUS_URI=`getent hosts mimir | awk '{print $1}'`
export LOKI_URI=`getent hosts loki | awk '{print $1}'`

export COLORED_OUTPUT=false
export PREPEND_DATE=false

## [cmd] [script] generate_consul_monitoring_config.sh
_RUN_CMD -c "~/ops/scenarios/00_base_scenario_files/supporting_scripts/generate_consul_monitoring_config.sh"

md_log 'The script creates the Grafana Agent configuration for all agents.'

_RUN_CMD -c 'tree ${OUTPUT_FOLDER}monitoring'

### H3 .........................................................................
md_h3 "Copy configuration on client VMs" 
# ..............................................................................  

NODES_ARRAY=( "consul-server-0" "hashicups-db-0" "hashicups-api-0" "hashicups-frontend-0" "hashicups-nginx-0" "gateway-api-0" )
NAMES_ARRAY=( "Consul server" "Database" "API" "Frontend" "NGINX" "API gateway" )

_name_count=0

for node in "${NODES_ARRAY[@]}"; do

  md_log 'Copy configuration on `'${node}'`.'

  _RUN_CMD 'rsync -av \
 	-e "ssh -i ~/certs/id_rsa" \
 	${OUTPUT_FOLDER}monitoring/grafana-agent-'${node}'.yaml \
 	'${node}':grafana-agent.yaml'

done

##  H2 -------------------------------------------------------------------------
md_h2 "Start Grafana Agent on VMs"
# ------------------------------------------------------------------------------

md_log 'Once you copied the configuration files on the different VMs, login on each Consul client VMs and start the Grafana Agent.'

_name_count=0

for node in "${NODES_ARRAY[@]}"; do

  ### H3 .........................................................................
  md_h3 "Start Grafana Agent for ${NAMES_ARRAY[$_name_count]}" 
  # ..............................................................................  

  _CONNECT_TO ${node}

  md_log 'Start the Grafana Agent.'

  _RUN_CMD -r ${node} -h 'grafana-agent -config.file ~/grafana-agent.yaml > /tmp/grafana-agent.log 2>&1 &'

  _EXIT_FROM ${node}

  _name_count=`expr ${_name_count} + 1`

done

