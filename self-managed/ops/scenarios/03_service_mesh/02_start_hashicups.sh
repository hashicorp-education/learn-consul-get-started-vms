#!/usr/bin/env bash

# ++-----------
# ||   02 - Start HashiCups Application
# ++------

# ++-----------------+
# || Variables       |
# ++-----------------+


# ++-----------------+
# || Begin           |
# ++-----------------+
header1 "Starting Application"

## [ux-diff] [cloud provider] UX differs across different Cloud providers
if [ "${SCENARIO_CLOUD_PROVIDER}" == "docker" ]; then

    log "Application pre-installed. Starting."

elif [ "${SCENARIO_CLOUD_PROVIDER}" == "aws" ]; then
    ## [ ] [test] check if still works in AWS

    header2 "Upgrading Application."

    log "Cleaning existing version."
    remote_exec hashicups-db "rm -f ~/start_service.sh" > /dev/null 2>&1
    remote_exec hashicups-api "rm -f ~/start_service.sh" > /dev/null 2>&1
    remote_exec hashicups-frontend "rm -f ~/start_service.sh" > /dev/null 2>&1
    remote_exec hashicups-nginx "rm -f ~/start_service.sh" > /dev/null 2>&1
    log "Deployment state cleaned"

    log "Installing new version."
    remote_copy hashicups-db ${ASSETS}scenario/start_hashicups_db.sh ~/start_service.sh
    remote_copy hashicups-api ${ASSETS}scenario/start_hashicups_api.sh ~/start_service.sh
    remote_copy hashicups-frontend ${ASSETS}scenario/start_hashicups_fe.sh ~/start_service.sh
    remote_copy hashicups-nginx ${ASSETS}scenario/start_hashicups_nginx.sh ~/start_service.sh
    log "Deployment state cleaned"
else 
    log_err "Cloud provider $SCENARIO_CLOUD_PROVIDER is unsupported...exiting."
    exit 245
fi


header2 "Starting HashiCups Application"

header3 "Starting Database"
remote_exec hashicups-db "bash ~/start_service.sh" > /dev/null 2>&1
log "HashiCups Database Started"

header3 "Starting API"
remote_exec hashicups-api "bash ~/start_service.sh" > /dev/null 2>&1
log "HashiCups API Started"

header3 "Starting Frontend"
remote_exec hashicups-frontend "bash ~/start_service.sh" > /dev/null 2>&1
log "HashiCups Frontend Started"

header3 "Starting Nginx"
remote_exec hashicups-nginx "bash ~/start_service.sh" > /dev/null 2>&1
log "HashiCups Nginx Started"
