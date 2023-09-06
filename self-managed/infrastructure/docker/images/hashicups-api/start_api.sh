#!/bin/bash

if [ ! -z `pidof java` ]; then kill -9 `pidof java`; fi
if [ ! -z `pidof product-api` ]; then kill -9 `pidof product-api`; fi
if [ ! -z `pidof public-api` ]; then kill -9 `pidof public-api`; fi

## Check Parameters
if   [ "$1" == "local" ]; then
    echo "Starting service on local interface."
    
    ## Configure Product API
    tee /home/admin/conf.json << EOF
{
	"db_connection": "host=localhost port=5432 user=postgres password=p05tgr35 dbname=products sslmode=disable",
	"bind_address": "localhost:9090",
	"metrics_address": "localhost:9103"
}
EOF

    ## Configure Public API
    export BIND_ADDRESS="localhost:8081"

else
    echo "Starting service on global interface."

    ## Configure Product API
    tee /home/admin/conf.json << EOF
{
	"db_connection": "host=hashicups-db port=5432 user=postgres password=p05tgr35 dbname=products sslmode=disable",
	"bind_address": ":9090",
	"metrics_address": ":9103"
}
EOF

    ## Configure Public API
    export BIND_ADDRESS=":8081"
fi

echo "Starting payments application"
java -jar /bin/spring-boot-payments.jar > /tmp/payments.log 2>&1 &

echo "Starting Product API"
export CONFIG_FILE="/home/admin/conf.json"
/bin/product-api > /tmp/product_api.log 2>&1 &

echo "Starting Public API"
export PRODUCT_API_URI="http://localhost:9090"
export PAYMENT_API_URI="http://localhost:8080"
/bin/public-api > /tmp/public_api.log 2>&1 &

