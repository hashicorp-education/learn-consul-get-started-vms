#!/usr/bin/env bash

# ++-----------
# ||   01 - Setup Bastion Host
# ++------

# ++-----------------+
# || Variables       |
# ++-----------------+

# Create necessary directories to operate
mkdir -p ${ASSETS}
mkdir -p ${LOGS}

# PATH=$PATH:/home/app/bin
# SSH_OPTS="StrictHostKeyChecking=accept-new"

## Instruqt compatibility
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

if [ "${START_MONITORING_SUITE}" == "true" ]; then

  log "Configuring DNS for monitoring suite"

  ## [warn] Cloud provider breaking point
  ## [feat] Make conditional check on Cloud provider
  ## The following steps only work on AWS. Use the reference link for ideas on
  ## how to make platform independent.  
  ## https://github.com/hashicorp-education/learn-nomad-getting-started/blob/main/shared/data-scripts/user-data-client.sh
  export PROMETHEUS_URI=$(curl -s http://instance-data/latest/meta-data/local-ipv4)
  export GRAFANA_URI=$(curl -s http://instance-data/latest/meta-data/public-ipv4)

  # sudo cat <<EOT >> /etc/hosts
  sudo tee -a /etc/hosts > /dev/null <<EOT

# The following lines are used by the monitoring suite
${PROMETHEUS_URI} mimir loki prometheus
${GRAFANA_URI} grafana
EOT

  log "Starting monitoring suite on Bastion Host"
  bash ${ASSETS}scenario/start_monitoring_suite.sh

  

  
fi

