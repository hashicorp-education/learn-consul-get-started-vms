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
if [[ ! -z "${INSTRUQT_PARTICIPANT_ID}" ]]; then
    FQDN_SUFFIX=".$INSTRUQT_PARTICIPANT_ID.svc.cluster.local"
else
    FQDN_SUFFIX=""
fi

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

# log_err $LOG_FILES_CREATED
# log_err $LOG_PROVISION

# exit 0

## Create Logfiles
echo -e "Scenario started at `date '+%Y-%m-%d %H:%M:%S'`\n" > ${LOG_FILES_CREATED}
echo "Scenario started at `date '+%Y%m%d%H%M.%S'`" > ${LOG_PROVISION}

## Checks if the monitoring suite needs to be started with this scenario
## All the Getting Started scenarios on AWS and Azure will have this set 
## to true to permit a single infrastructure provision to follow along
## the whole tutorial collection.
## Docker and Instruqt scenarios will have this set to false because
## infrastructure for them is much faster.

if [ "${START_MONITORING_SUITE}" == "true" ]; then

  ## [ux-diff] [cloud provider] UX differs across different Cloud providers
  if [ "${SCENARIO_CLOUD_PROVIDER}" == "docker" ]; then
    log "Cloud provider is: $SCENARIO_CLOUD_PROVIDER"

    export PROMETHEUS_URI=mimir
    export GRAFANA_URI=grafana
    export LOKI_URI=loki

  elif [ "${SCENARIO_CLOUD_PROVIDER}" == "aws" ]; then
    ## [ ] [test] check if still works in AWS
    log "Cloud provider is: $SCENARIO_CLOUD_PROVIDER"

    ## The following steps only work on AWS. Use the reference link for ideas on
    ## how to make platform independent.  
    ## https://github.com/hashicorp-education/learn-nomad-getting-started/blob/main/shared/data-scripts/user-data-client.sh
    TOKEN=$(curl -X PUT "http://instance-data/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")

    export PROMETHEUS_URI=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" http://instance-data/latest/meta-data/local-ipv4)
    export GRAFANA_URI=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" http://instance-data/latest/meta-data/public-ipv4)
    export LOKI_URI=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" http://instance-data/latest/meta-data/local-ipv4)
    
    log "Configuring DNS for monitoring suite"
    
    # sudo cat <<EOT >> /etc/hosts
    sudo tee -a /etc/hosts > /dev/null <<EOT

# The following lines are used by the monitoring suite
${PROMETHEUS_URI} mimir loki prometheus
${GRAFANA_URI} grafana
EOT

    log "Starting monitoring suite on Bastion Host"
    bash "${SCENARIO_OUTPUT_FOLDER}start_monitoring_suite.sh"

  else 
    log_err "Cloud provider $SCENARIO_CLOUD_PROVIDER is unsupported...exiting."
    exit 245
  fi
fi

## Generate list of created files during scenario step
## The list is appended to the $LOG_FILES_CREATED file
get_created_files