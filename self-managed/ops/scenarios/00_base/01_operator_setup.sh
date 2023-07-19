#!/usr/bin/env bash

# ++-----------
# ||   01 - Setup Bastion Host
# ++------

# ++-----------------+
# || Variables       |
# ++-----------------+

# Create necessary directories to operate
mkdir -p "${ASSETS}"
mkdir -p "${LOGS}"

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

    export PROMETHEUS_URI=prometheus
    export GRAFANA_URI=grafana
    export LOKI_URI=loki

  elif [ "${SCENARIO_CLOUD_PROVIDER}" == "aws" ]; then
    ## [ ] [test] check if still works in AWS
    log "Cloud provider is: $SCENARIO_CLOUD_PROVIDER"

    ## The following steps only work on AWS. Use the reference link for ideas on
    ## how to make platform independent.  
    ## https://github.com/hashicorp-education/learn-nomad-getting-started/blob/main/shared/data-scripts/user-data-client.sh
    export PROMETHEUS_URI=$(curl -s http://instance-data/latest/meta-data/local-ipv4)
    export GRAFANA_URI=$(curl -s http://instance-data/latest/meta-data/public-ipv4)

    log "Configuring DNS for monitoring suite"
    
    # sudo cat <<EOT >> /etc/hosts
    sudo tee -a /etc/hosts > /dev/null <<EOT

# The following lines are used by the monitoring suite
${PROMETHEUS_URI} mimir loki prometheus
${GRAFANA_URI} grafana
EOT

    log "Starting monitoring suite on Bastion Host"
    bash "${ASSETS}scenario/start_monitoring_suite.sh"

  else 
    log_err "Cloud provider $SCENARIO_CLOUD_PROVIDER is unsupported...exiting."
    exit 245
  fi
fi

