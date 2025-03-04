#!/bin/bash

#!/usr/bin/env bash

## Service file to start HashiCups services in the different VM based scenarios.
## For production environments it is recommended to use systemd service files, 
## this file is more complex than needed in order to take into account all possible
## situation an HashiCups service might get started in the different use-cases.

## Possible uses:
## -----------------------------------------------------------------------------
## service.sh                       -   [Compatibility mode] Starts the service on all available interfaces  
## service.sh local                 -   [Compatibility mode] Starts the service on localhost interface
## service.sh start                 -   Starts the service using hostnames for upstream services
## service.sh start --local         -   Starts the service on localhost interface
## service.sh start --hostname      -   Starts the service using hostnames for upstream services
## service.sh start --consul        -   Starts the service using Consul service name for upstream services (using LB functionality)
## service.sh start --consul-node   -   Starts the service using Consul node name for upstream services
## service.sh stop                  -   Stops the service
## service.sh reload                -   Reload the service without changing the configuration files
## service.sh reload --local        -   Reload the service without changing the configuration files. If variables need to be set, are set on localhost.

echo '# ------------------------------------ #'
echo '|      HashiCups Frontend service      |'
echo '# ------------------------------------ #'

## ----------
## Variables
## -----------------------------------------------------------------------------

## If set to true the service is started locally
SERVICE_MESH=false

LOGFILE="/tmp/frontend.log"

## Setting configuration variables.
export NEXT_PUBLIC_PUBLIC_API_URL=/

echo "Checking for NEXT_PUBLIC_PUBLIC_API_URL env var"
test -n "$NEXT_PUBLIC_PUBLIC_API_URL"
find /app/.next \( -type d -name .git -prune \) -o -type f -print0 | xargs -0 sed -i "s#APP_NEXT_PUBLIC_API_URL#$NEXT_PUBLIC_PUBLIC_API_URL#g"

echo "Checking for NEXT_PUBLIC_FOOTER_FLAG env var"
test -n "$NEXT_PUBLIC_FOOTER_FLAG"
find /app/.next \( -type d -name .git -prune \) -o -type f -print0 | xargs -0 sed -i "s#APP_PUBLIC_FOOTER_FLAG#$NEXT_PUBLIC_FOOTER_FLAG#g"

## ----------
## Stop pre-existing instances.
## -----------------------------------------------------------------------------
echo "Stop pre-existing instances."

killall node >> ${LOGFILE} 2>&1 &

sleep 1

## -----------------------------------------------------------------------------



## ----------
## Check script command
## -----------------------------------------------------------------------------
case "$1" in
    "")
        echo "EMPTY - Start services on all interfaces."
        ;;
    "local")
        echo "LOCAL - Start services on local interface."
        SERVICE_MESH=true
        ;;
    "start")
        echo "START - Start services on all interfaces."
        case "$2" in
        ""|"--hostname")
            echo "START - Start services on all interfaces using hostnames for upstream services."
            ;;
        "--local")
            echo "START LOCAL - Start services on local interface."
            SERVICE_MESH=true
            ;;
        "--consul")
            echo "START CONSUL - Starts the service using Consul service name for upstream services (using LB functionality)."
            echo "NOT APPLICABLE FOR THIS SERVICE - No Upstreams to define."
            ;;
        "--consul-node")
            echo "START CONSUL - Starts the service using Consul node name for upstream services."
            echo "NOT APPLICABLE FOR THIS SERVICE - No Upstreams to define."
            ;;
        *) echo "$0 $1: error - unrecognized option $2" 1>&2; exit 2;;
        esac 
        ;;
    "stop")
        echo "Service instance stopped." 
        exit 0
        ;;
    "reload")
        echo "RELOAD - Start services on all interfaces."
        case "$2" in
            "")
                echo "RELOAD - Reload the service without changing the configuration files"
                echo "NOT APPLICABLE FOR THIS SERVICE - A full restart is going to be performed."
                ;;
            "--local")
                echo "RELOAD LOCAL - Reload the service without changing the configuration files. If variables need to be set, are set on localhost."
                echo "NOT APPLICABLE FOR THIS SERVICE - A full restart, on local interface, is going to be performed."
                SERVICE_MESH=true
                ;;
        
            *) echo "$0 $1: error - unrecognized option $2" 1>&2; exit 2;;
        esac
        ;;
    *) echo "$0: error - unrecognized option $1" 1>&2; exit 1;;
esac

## -----------------------------------------------------------------------------


## ----------
## Start instances.
## -----------------------------------------------------------------------------
echo "Start service instance."

cd /app || exit

if [ "${SERVICE_MESH}" == true ]; then
    
    echo "Starting HashiCups Frontend on local interface."
    /app/node_modules/.bin/next start --hostname "127.0.0.1" >> ${LOGFILE} 2>&1 &

else
    
    echo "Starting HashiCups Frontend."
    /app/node_modules/.bin/next start >> ${LOGFILE} 2>&1 &

fi

cd ~ || exit

## -----------------------------------------------------------------------------



