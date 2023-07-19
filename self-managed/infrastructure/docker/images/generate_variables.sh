#!/usr/bin/env bash

# ++-----------------+
# || Functions       |
# ++-----------------+

## Returns the lates compatible envoy version for the Consul version passed as argument
function get_envoy_version() {

    CONSUL_VER=$1

    CONSUL_VER=`echo ${CONSUL_VER} | sed 's/\.[0-9]*$/.x/g'`

    ## [warn] [flow] Get compatible Envoy Version relies on a web page content
    ## Logic
    ## 00 Download the page source
    ## 01 Select all tables in the page
    ## 02 Select only the table that contains "Compatible Envoy Versions" text
    ## 03 Select only the line that contains the Consul version we want
    ## 04 Select only the version numbers (Pattern "x.y.x,")
    ## 05 Select only the first value

    ENVOY_VER=`wget https://www.consul.io/docs/connect/proxies/envoy -q -O - | \
        grep -oP "<table>.*?</table>" | \
        grep "Compatible Envoy Versions" | \
        grep -oP "<tr><td>${CONSUL_VER}</td>.*?</tr>" | \
        grep -oP "\d+\.\d+.\d+," | \
        sed 's/,//g' | \
        head -1`
    
    echo ${ENVOY_VER}
}

function get_latest_consul_version() {

	CHECKPOINT_URL="https://checkpoint-api.hashicorp.com/v1/check"
    if [ -z "$1" ] || [ "$1" == "latest" ] ; then
        CONSUL_VER=$(curl -s "${CHECKPOINT_URL}"/consul | jq .current_version | tr -d '"')
    fi

	echo "${CONSUL_VER}"
}

function get_latest_app_version() {

    APP_NAME=$1

    APP_VER=`wget -q https://registry.hub.docker.com/v1/repositories/$1/tags -O -  | \
            jq -r ".[].name"  | \
            sort -Vr | \
            grep -e "^v[0-9]*\.[0-9]*\.[0-9]*" | \
            head -1  | sed 's/^v//g'`
    
    echo $APP_VER
}

# ++-----------------+
# || Variables       |
# ++-----------------+

## DOCKER Variables
## Sets up a mock Docker repo, images will be built locally
DOCKER_REPOSITORY="learn-consul"
DOCKER_BASE_IMAGE="base-image"
DOCKER_BASE_CONSUL="base-consul"

### VERSIONS
## HashiCorp tools
# CONSUL_LATEST=`get_latest_consul_version`
# CONSUL_VERSION=${CONSUL_VERSION:-$CONSUL_LATEST}

## The script is intended to produce Docker images for the latest available 
## Consul version, with the latest compatible Envoy version.
## [warn] This might only work with GNU version of sed and grep.
LAST_CONSUL_VERSION=`get_latest_consul_version`
LAST_COMPATIBLE_ENVOY_VERSION=`get_envoy_version ${LAST_CONSUL_VERSION}`

## [core] [flow] tune here to chenge HashiCups Configuration
## HashiCups
HC_DB_VERSION="v0.0.22"
HC_API_PAYMENTS_VERSION="latest"
HC_API_PRODUCT_VERSION="v0.0.22"
HC_API_PUBLIC_VERSION="v0.0.7"
HC_FE_VERSION="v1.0.9"


## The script is used to produce a valid configuration for `build_images.sh`
## The configuration will be saved on a file, sourced by the script.
OUTPUT_FILE=./variables.env

# ++-----------------+
# || Begin           |
# ++-----------------+

echo "#!/usr/bin/env bash"                                  > ${OUTPUT_FILE}

echo "CONSUL_VERSION=$LAST_CONSUL_VERSION"                  >> ${OUTPUT_FILE}
echo "ENVOY_VERSION=$LAST_COMPATIBLE_ENVOY_VERSION"         >> ${OUTPUT_FILE}

echo "DOCKER_REPOSITORY=${DOCKER_REPOSITORY}"               >> ${OUTPUT_FILE}
echo "DOCKER_BASE_IMAGE=${DOCKER_BASE_IMAGE}"               >> ${OUTPUT_FILE}
echo "DOCKER_BASE_CONSUL=${DOCKER_BASE_CONSUL}"             >> ${OUTPUT_FILE}

echo "HC_API_PAYMENTS_VERSION=${HC_API_PAYMENTS_VERSION}"   >> ${OUTPUT_FILE}
echo "HC_API_PRODUCT_VERSION=${HC_API_PRODUCT_VERSION}"     >> ${OUTPUT_FILE}
echo "HC_API_PUBLIC_VERSION=${HC_API_PUBLIC_VERSION}"       >> ${OUTPUT_FILE}
