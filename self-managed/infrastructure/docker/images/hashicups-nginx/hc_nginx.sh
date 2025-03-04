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
echo '|       HashiCups NGINX service        |'
echo '# ------------------------------------ #'

## ----------
## Variables
## -----------------------------------------------------------------------------

## If set to true the service is started locally
SERVICE_MESH=false
## If set to false the service is re-started with the same configuration.
REGEN_CONFIG=true
## Consul Node upstream
CONSUL_NODE=false
## Consul Service upstream
CONSUL_SERVICE=false

## NGINX will not start if it cannot resolve upstream DNS names.
## One of the services, hashicups-api, might take up to 10 seconds to be 
## healthy in Consul and to be resolved by Consul DNS. 
## For this reason, when running the service using service discovery and 
## Consul DNS to resolve the upstream name the script will try multiple times
## and wait between the different attemps a number of second to give Consul
## time to recognice the hashicups-api service as healthy. 
START_ATTEMPT=1
SLEEP_INTERVAL=1

_API_ADDRESS="hashicups-api-0"
_FE_ADDRESS="hashicups-frontend-0"

## ----------
## Stop pre-existing instances.
## -----------------------------------------------------------------------------
echo "Stop pre-existing instances."

if [ ! `pidof nginx | wc -w` -eq "0" ]; then kill -9 `pidof nginx`; fi

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
        "--ingress")
            echo "START AS INGRESS - Starts the service on all interfaces and connects to upstreams in the service mesh."
            SERVICE_MESH=true
            ;;
        "--consul")
            echo "START CONSUL - Starts the service using Consul service name for upstream services (using LB functionality)."
            CONSUL_SERVICE=true
            DNS_LOOKUP="service"
            _API_ADDRESS="hashicups-api"
            _FE_ADDRESS="hashicups-frontend"
            ;;
        "--consul-node")
            echo "START CONSUL - Starts the service using Consul node name for upstream services."
            CONSUL_NODE=true
            DNS_LOOKUP="node"
            _API_ADDRESS="hashicups-api-0"
            _FE_ADDRESS="hashicups-frontend-0"
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
                REGEN_CONFIG=false
                ;;
            "--local")
                echo "RELOAD LOCAL - Reload the service without changing the configuration files. If variables need to be set, are set on localhost."
                SERVICE_MESH=true
                REGEN_CONFIG=false
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

if [ "${SERVICE_MESH}" == true ]; then
    echo "Service started on local insteface"
    
    tee /etc/nginx/conf.d/def_upstreams.conf << EOF
upstream frontend_upstream {
    server localhost:3000;
}

upstream api_upstream {
    server localhost:8081;
}
EOF

else
    echo "Service started to listen on all available interfaces."

    START_ATTEMPT=5
    SLEEP_INTERVAL=5

    if [ "${REGEN_CONFIG}" == true ]; then

        if [ "${CONSUL_NODE}" == true ] || [ "${CONSUL_SERVICE}" == true ]; then

            _DC=`cat /etc/consul.d/consul.hcl | grep datacenter | awk '{print $3}' | sed 's/"//g'`
            _DOMAIN=`cat /etc/consul.d/consul.hcl | grep domain | awk '{print $3}' | sed 's/"//g'`

            if [ "${_DC}" == "" ]; then _DC="dc1"; fi
            if [ "${_DOMAIN}" == "" ]; then _DOMAIN="consul"; fi

            tee /etc/nginx/conf.d/def_upstreams.conf << EOF
upstream frontend_upstream {
    server ${_FE_ADDRESS}.${DNS_LOOKUP}.${_DC}.${_DOMAIN}:3000;
}

upstream api_upstream {
    server ${_API_ADDRESS}.${DNS_LOOKUP}.${_DC}.${_DOMAIN}:8081;
}
EOF
        else

        tee /etc/nginx/conf.d/def_upstreams.conf << EOF
upstream frontend_upstream {
    server hashicups-frontend-0:3000;
}

upstream api_upstream {
    server hashicups-api-0:8081;
}
EOF

        fi

    fi
fi

for i in `seq ${START_ATTEMPT}`; do

    if [ `pidof nginx | wc -w` -eq "0" ]; then
        echo "Starting NGINX...attempt $i" 
        /usr/sbin/nginx >> /tmp/nginx.log 2>&1 &
        sleep ${SLEEP_INTERVAL}
    fi

done

## -----------------------------------------------------------------------------
