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
echo '|        HashiCups API service         |'
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
## DNS Lookup to use to compose the FQDN for the services
DNS_LOOKUP=""

# BIND_ADDRESS="localhost"
# DATABASE_ADDRESS="localhost"

_BIND_ADDR=""
_DATABASE_ADDRESS="hashicups-db-0"


## ----------
## Stop pre-existing instances.
## -----------------------------------------------------------------------------
echo "Stop pre-existing instances."

if [ ! -z `pidof java` ]; then kill -9 `pidof java`; fi
if [ ! -z `pidof product-api` ]; then kill -9 `pidof product-api`; fi
if [ ! -z `pidof public-api` ]; then kill -9 `pidof public-api`; fi

## -----------------------------------------------------------------------------


## ----------
## Check script command
## -----------------------------------------------------------------------------
case "$1" in
    "")
        echo "EMPTY - Start services on all interfaces."
        # BIND_ADDRESS=""
        # DATABASE_ADDRESS="hashicups-db-0"
        ;;
    "local")
        echo "LOCAL - Start services on local interface."
        SERVICE_MESH=true
        _BIND_ADDR="localhost"
        _DATABASE_ADDRESS="localhost"
        ;;
    "start")
        echo "START - Start services on all interfaces."
        case "$2" in
        ""|"--hostname")
            echo "START - Start services on all interfaces using hostnames for upstream services."
            _BIND_ADDR=""
            # DATABASE_ADDRESS="hashicups-db-0"
            ;;
        "--local")
            echo "START LOCAL - Start services on local interface."
            SERVICE_MESH=true
            _BIND_ADDR="localhost"
            _DATABASE_ADDRESS="localhost"
            ;;
        "--consul")
            echo "START CONSUL - Starts the service using Consul service name for upstream services (using LB functionality)."
            _BIND_ADDR=""
            _DATABASE_ADDRESS="hashicups-db"
            CONSUL_SERVICE=true
            DNS_LOOKUP="service"
            ;;
        "--consul-node")
            echo "START CONSUL - Starts the service using Consul node name for upstream services."
            _BIND_ADDR=""
            _DATABASE_ADDRESS="hashicups-db-0"
            CONSUL_NODE=true
            DNS_LOOKUP="node"
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
                _BIND_ADDR=""
                _DATABASE_ADDRESS="hashicups-db-0"
                ;;
            "--local")
                echo "RELOAD LOCAL - Reload the service without changing the configuration files. If variables need to be set, are set on localhost."
                SERVICE_MESH=true
                REGEN_CONFIG=false
                _BIND_ADDR="localhost"
                _DATABASE_ADDRESS="localhost"
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

export BIND_ADDRESS=${_BIND_ADDR}:8081



if [ "${SERVICE_MESH}" == true ]; then
    echo "Service started on local insteface"
    
    ## Configure Product API
    tee /home/admin/conf.json << EOF
{
	"db_connection": "host=localhost port=5432 user=hashicups password=hashicups_pwd dbname=products sslmode=disable",
	"bind_address": "localhost:9090",
	"metrics_address": "localhost:9103"
}
EOF

else
    echo "Service started to listen on all available interfaces."
    if [ "${REGEN_CONFIG}" == true ]; then

        if [ "${CONSUL_NODE}" == true ] || [ "${CONSUL_SERVICE}" == true ]; then

            _DC=`cat /etc/consul.d/consul.hcl | grep datacenter | awk '{print $3}' | sed 's/"//g'`
            _DOMAIN=`cat /etc/consul.d/consul.hcl | grep domain | awk '{print $3}' | sed 's/"//g'`

            if [ "${_DC}" == "" ]; then _DC="dc1"; fi
            if [ "${_DOMAIN}" == "" ]; then _DOMAIN="consul"; fi

            ## Configure Product API
            tee /home/admin/conf.json << EOF
{
	"db_connection": "host=${_DATABASE_ADDRESS}.${DNS_LOOKUP}.${_DC}.${_DOMAIN} port=5432 user=hashicups password=hashicups_pwd dbname=products sslmode=disable",
	"bind_address": ":9090",
	"metrics_address": ":9103"
}
EOF
        else
            ## Configure Product API
            tee /home/admin/conf.json << EOF
{
	"db_connection": "host=${_DATABASE_ADDRESS} port=5432 user=hashicups password=hashicups_pwd dbname=products sslmode=disable",
	"bind_address": ":9090",
	"metrics_address": ":9103"
}
EOF
        fi


    fi
fi


## Once configuration is created startup process is equivalent for all cases.
echo "Starting payments application"
java -jar /bin/spring-boot-payments.jar > /tmp/payments.log 2>&1 &

echo "Starting Product API"
export CONFIG_FILE="/home/admin/conf.json"
/bin/product-api > /tmp/product_api.log 2>&1 &

echo "Starting Public API"
export PRODUCT_API_URI="http://localhost:9090"
export PAYMENT_API_URI="http://localhost:8080"
/bin/public-api > /tmp/public_api.log 2>&1 &

## -----------------------------------------------------------------------------
