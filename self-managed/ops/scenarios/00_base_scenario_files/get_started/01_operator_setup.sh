#!/usr/bin/env bash

# ++-----------
# ||   01 - Setup Bastion Host
# ++------
header1 "Prerequisites - Setup Bastion Host and Monitoring suite"

# ++-----------------+
# || Variables       |
# ++-----------------+

## Instruqt compatibility
## [ ] [instruqt] check if this part is still needed
# if [[ ! -z "${INSTRUQT_PARTICIPANT_ID}" ]]; then
#     FQDN_SUFFIX=".$INSTRUQT_PARTICIPANT_ID.svc.cluster.local"
# else
#     FQDN_SUFFIX=""
# fi

# # ++-----------------+
# # || Functions       |
# # ++-----------------+

# ++-----------------+
# || Begin           |
# ++-----------------+

## Create necessary directories to operate
mkdir -p "${ASSETS}"
mkdir -p "${LOGS}"

LOG_FILES_CREATED="${LOGS}${LOG_FILES_CREATED_NAME}"
LOG_PROVISION="${LOGS}${LOG_PROVISION_NAME}"

## Create Logfiles
echo -e "Scenario started at `date '+%Y-%m-%d %H:%M:%S'`\n" > ${LOG_FILES_CREATED}
echo "Scenario started at `date '+%Y%m%d%H%M.%S'`" > ${LOG_PROVISION}

## Make supporting scripts executable
chmod +x ~/ops/scenarios/00_base_scenario_files/supporting_scripts/*

## Checks if the monitoring suite needs to be started with this scenario
## All the Getting Started scenarios on AWS and Azure will have this set 
## to true to permit a single infrastructure provision to follow along
## the whole tutorial collection.
## Docker and Instruqt scenarios will have this set to false because
## infrastructure for them is much faster.

if [ "${ENABLE_MONITORING}" == "true" ]; then

  ## [ux-diff] [cloud provider] UX differs across different Cloud providers
  if [ "${SCENARIO_CLOUD_PROVIDER}" == "docker" ]; then
    log "Cloud provider is: $SCENARIO_CLOUD_PROVIDER"
    # export PROMETHEUS_URI=mimir
    # export GRAFANA_URI=grafana
    # export LOKI_URI=loki

    export PROMETHEUS_URI=`dig +short mimir`
    export GRAFANA_URI=`dig +short grafana`
    export LOKI_URI=`dig +short loki`

    # In Docker we change the port number for Grafana Web UI to not conflict with other apps using the same port 
    export GRAFANA_PORT=3001
    # In Docker we expose the Grafana Web UI on localhost. Change this in instruqt
    export GRAFANA_URI="127.0.0.1"

  elif [ "${SCENARIO_CLOUD_PROVIDER}" == "aws" ]; then
    log "Cloud provider is: $SCENARIO_CLOUD_PROVIDER"

    ## The following steps only work on AWS. Use the reference link for ideas on
    ## how to make platform independent.  
    ## https://github.com/hashicorp-education/learn-nomad-getting-started/blob/main/shared/data-scripts/user-data-client.sh
    export PROMETHEUS_URI=$(curl -s http://instance-data/latest/meta-data/local-ipv4)
    export GRAFANA_URI=$(curl -s http://instance-data/latest/meta-data/public-ipv4)
    export LOKI_URI=$(curl -s http://instance-data/latest/meta-data/local-ipv4)
    
    ## Fallback in case the API does not work
    if [ -z "${GRAFANA_URI}" ]; then
      
      log_warn "AWS API not working for public IP. Fallback to external service."
      export GRAFANA_URI=$(curl -s ifconfig.me)
      export LOKI_URI=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)
      export PROMETHEUS_URI=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)

    fi

    ## Errors in case the fallback method does not work.
    if [ -z "${GRAFANA_URI}" ]; then

      log_err "Fallback not working. Grafana dashboard might not work properly."
      export GRAFANA_URI="127.0.0.1"
      export LOKI_URI="127.0.0.1"
      export PROMETHEUS_URI="127.0.0.1"

    fi

    log "Configuring DNS for monitoring suite"
    
    # sudo cat <<EOT >> /etc/hosts
    sudo tee -a /etc/hosts > /dev/null <<EOT

# The following lines are used by the monitoring suite
${PROMETHEUS_URI} mimir loki prometheus
${GRAFANA_URI} grafana
EOT

    log "Starting monitoring suite on Bastion Host"
    bash "${SCENARIO_OUTPUT_FOLDER}start_monitoring_suite.sh"

elif [ "${SCENARIO_CLOUD_PROVIDER}" == "azure" ]; then
    ## [ ] [test] check if still works in Azure
    log "Cloud provider is: $SCENARIO_CLOUD_PROVIDER"

    ## The following steps only work on Azure. Use the reference link for ideas on
    ## how to make platform independent.  
    ## https://github.com/hashicorp-education/learn-nomad-getting-started/blob/main/shared/data-scripts/user-data-client.sh
    export PROMETHEUS_URI=$(curl -s -H Metadata:true --noproxy "*" http://169.254.169.254/metadata/instance/network/interface/0/ipv4/ipAddress/0?api-version=2021-12-13 | jq -r '.["privateIpAddress"]')
    export GRAFANA_URI=$(curl -s -H Metadata:true --noproxy "*" http://169.254.169.254/metadata/instance/network/interface/0/ipv4/ipAddress/0?api-version=2021-12-13 | jq -r '.["publicIpAddress"]')
    export LOKI_URI=$(curl -s -H Metadata:true --noproxy "*" http://169.254.169.254/metadata/instance/network/interface/0/ipv4/ipAddress/0?api-version=2021-12-13 | jq -r '.["privateIpAddress"]')
    
    ## Fallback in case the API does not work
    if [ -z "${GRAFANA_URI}" ]; then

      log_warn "Azure API not working for public IP. Fallback to external service."
      export GRAFANA_URI=$(curl -s ifconfig.me)

    fi

    ## Errors in case the fallback method does not work.
    if [ -z "${GRAFANA_URI}" ]; then

      log_err "Fallback not working. Grafana dashboard might not work properly."
      export GRAFANA_URI="127.0.0.1"

    fi

    log "Configuring DNS for monitoring suite"
    
    # sudo cat <<EOT >> /etc/hosts
    sudo tee -a /etc/hosts > /dev/null <<EOT

# The following lines are used by the monitoring suite
${PROMETHEUS_URI} mimir loki prometheus
${GRAFANA_URI} grafana
EOT

    log "Starting monitoring suite on Bastion Host"
    bash "${SCENARIO_OUTPUT_FOLDER}start_monitoring_suite.sh"

    log_warn "GRAFANA IP ADDR: $GRAFANA_URI"

  else 
    log_err "Cloud provider $SCENARIO_CLOUD_PROVIDER is unsupported...exiting."
    exit 245
  fi
fi

## Generate list of created files during scenario step
## The list is appended to the $LOG_FILES_CREATED file
get_created_files


## Check remote connectivity
## This is a base prerequisite and also helps getting rid of the
## Warning: Permanently added 'consul-server-0' (ED25519) to the list of known hosts.
## messages on the provisioning logs.

header2 "Test SSH connectivity to VMs"

## To test connectivity creates a temporary file on the local node and copies it
## on all nodes, after copying it it tests SSH to remove it.

_tmp_file=`mktemp`

# sleep 10

## Consul servers
log "Test SSH for Consul server nodes"
for i in `seq 0 "$((CONSUL_SERVER_NUMBER-1))"`; do
  
  NODE_NAME="consul-server-$i"

  remote_copy ${NODE_NAME} ${_tmp_file} ${_tmp_file}
  remote_exec -s ${NODE_NAME} "rm -f ${_tmp_file}"

  _STAT="$?"

  if [ "${_STAT}" -ne 0 ];  then
    log_error "SSH connection error for consul-server-$i."
    exit 254
  fi
done

log "Test SSH for Gateway nodes"

for i in `seq ${api_gw_NUMBER}`; do

  NODE_NAME="gateway-api-$((i-1))"

  remote_copy ${NODE_NAME} ${_tmp_file} ${_tmp_file}
  remote_exec -s ${NODE_NAME} "rm -f ${_tmp_file}"

  _STAT="$?"

  if [ "${_STAT}" -ne 0 ];  then
    log_error "SSH connection error for ${NODE_NAME}."
    exit 254
  fi
done 

for i in `seq ${mesh_gw_NUMBER}`; do

  NODE_NAME="gateway-mesh-$((i-1))"
  
  remote_copy ${NODE_NAME} ${_tmp_file} ${_tmp_file}
  remote_exec -s ${NODE_NAME} "rm -f ${_tmp_file}"

  _STAT="$?"

  if [ "${_STAT}" -ne 0 ];  then
    log_error "SSH connection error for ${NODE_NAME}."
    exit 254
  fi
done 

for i in `seq ${term_gw_NUMBER}`; do

  NODE_NAME="gateway-terminating-$((i-1))"
  
  remote_copy ${NODE_NAME} ${_tmp_file} ${_tmp_file}
  remote_exec -s ${NODE_NAME} "rm -f ${_tmp_file}"

  _STAT="$?"

  if [ "${_STAT}" -ne 0 ];  then
    log_error "SSH connection error for ${NODE_NAME}."
    exit 254
  fi
done 

log "Test SSH for NIA nodes"

for i in `seq ${consul_esm_NUMBER}`; do

  NODE_NAME="consul-esm-$((i-1))"

  remote_copy ${NODE_NAME} ${_tmp_file} ${_tmp_file}
  remote_exec -s ${NODE_NAME} "rm -f ${_tmp_file}"

  _STAT="$?"

  if [ "${_STAT}" -ne 0 ];  then
    log_error "SSH connection error for ${NODE_NAME}."
    exit 254
  fi
done 

log "Test SSH for HashiCups service nodes"

NODES_ARRAY=( "hashicups-db" "hashicups-api" "hashicups-frontend" "hashicups-nginx" )

for node in "${NODES_ARRAY[@]}"; do

  NUM="${node/-/_}""_NUMBER"
  
  for i in `seq ${!NUM}`; do

    NODE_NAME="${node}-$((i-1))"

    remote_copy ${NODE_NAME} ${_tmp_file} ${_tmp_file}
    remote_exec -s ${NODE_NAME} "rm -f ${_tmp_file}"

    _STAT="$?"

    if [ "${_STAT}" -ne 0 ];  then
      log_error "SSH connection error for ${NODE_NAME}."
      exit 254
    fi
  done
done
