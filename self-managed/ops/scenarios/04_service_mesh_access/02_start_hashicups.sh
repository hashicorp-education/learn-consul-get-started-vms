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

header2 "Cleaning state before apply"
remote_exec hashicups-db "rm -f ~/start_service.sh" > /dev/null 2>&1
remote_exec hashicups-api "rm -f ~/start_service.sh" > /dev/null 2>&1
remote_exec hashicups-frontend "rm -f ~/start_service.sh" > /dev/null 2>&1
remote_exec hashicups-nginx "rm -f ~/start_service.sh" > /dev/null 2>&1
log "Deployment state cleaned"

header2 "Starting Database"
remote_copy hashicups-db ${ASSETS}scenario/start_hashicups_db.sh ~/start_service.sh
remote_exec hashicups-db "bash ~/start_service.sh" > /dev/null 2>&1
log "HashiCups Database Started"

header2 "Starting API"
remote_copy hashicups-api ${ASSETS}scenario/start_hashicups_api.sh ~/start_service.sh
remote_exec hashicups-api "bash ~/start_service.sh" > /dev/null 2>&1
log "HashiCups API Started"

header2 "Starting Frontend"
remote_copy hashicups-frontend ${ASSETS}scenario/start_hashicups_fe.sh ~/start_service.sh
remote_exec hashicups-frontend "bash ~/start_service.sh" > /dev/null 2>&1
log "HashiCups Frontend Started"

header2 "Starting Nginx"
remote_copy hashicups-nginx ${ASSETS}scenario/start_hashicups_nginx.sh ~/start_service.sh
remote_exec hashicups-nginx "bash ~/start_service.sh" > /dev/null 2>&1
log "HashiCups Nginx Started"
