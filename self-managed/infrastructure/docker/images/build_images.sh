#!/usr/bin/env bash

## Builds images for lab
## Image structure
## BASE: danielehc/consul-instruqt-base
## VERSION: The version for the image corresponds on the Consul version installed

# ++-----------------+
# || Functions       |
# ++-----------------+

## LOGGING
ts_log() {
  echo -e "\033[1m["$(date +"%Y-%m-%d %H:%M:%S")"] - ${@}\033[0m"
}

# ++-----------------+
# || Variables       |
# ++-----------------+

## FLOW
# Directory for building
BUILD_DIR=${1:-"./"}

## Folder where to store certificates
## [warn] If we change BUILD_DIR the folder will be created inside the new DIR
KEYS_DIR="./certs"

# Generates new certificates at every run
GEN_NEW_CERTS=${GEN_NEW_CERTS:-true}


## Import environment variables and functions
source "./variables.env"

# ++-----------------+
# || Begin           |
# ++-----------------+

pushd ${BUILD_DIR}base

## Generate SSH Keys
ts_log "Generate SSH Keys"

# Check if the folder for SSH keys exists
if [ -d "${KEYS_DIR}" ] ; then
  ## Folder exists, checking if we need to remove existing certs

  # If GEN_NEW_CERTS set to true remove existing certificates
  if [ "${GEN_NEW_CERTS}" == true ]; then
    rm -rf ${KEYS_DIR}/*
  fi

else
  ## Folder does not exist, create it
  mkdir -p "${KEYS_DIR}"
fi

## After the check if certificates are still in place use these ones otherwise create them
if [ "$(ls -A ${KEYS_DIR})" ]; then
  ts_log "Certificates found in ${KEYS_DIR}"
else
  ts_log "Creating certificates in ${KEYS_DIR}"

  pushd ${KEYS_DIR}

  ## Generate SSH keys for containers
  ssh-keygen -t rsa -b 4096 -f ./id_rsa -N ""

  popd 
fi


## Build base image

ts_log "Build Docker base image"

echo -e "- \033[1m\033[31m[Consul]\033[0m: ${CONSUL_VERSION}"
echo -e "- \033[1m\033[35m[Envoy]\033[0m: ${ENVOY_VERSION}"

IMAGE_TAG="${CONSUL_VERSION}"
LATEST_TAG="-t ${DOCKER_REPOSITORY}/${DOCKER_BASE_IMAGE}:latest"
LS_TAG="-t ${DOCKER_REPOSITORY}/${DOCKER_BASE_IMAGE}:${DOCKER_REPOSITORY}"

## Moving into the image folder
## The folder should contain the Dockerfile for the image

ts_log "Building \033[1m\033[33m${DOCKER_REPOSITORY}/${DOCKER_BASE_IMAGE}:v${IMAGE_TAG}\033[0m"



## Build Docker image
DOCKER_BUILDKIT=1 docker build \
  --build-arg CONSUL_VERSION=${CONSUL_VERSION} \
  --build-arg ENVOY_VERSION=v${ENVOY_VERSION} \
  -t "${DOCKER_REPOSITORY}/${DOCKER_BASE_IMAGE}:v${IMAGE_TAG}" ${LATEST_TAG} ${LS_TAG} . > /dev/null 2>&1

if [ $? != 0 ]; then
  ts_log "\033[1m\033[31m[ERROR]\033[0m - Failed build for ${DOCKER_REPOSITORY}/${DOCKER_BASE_IMAGE}:v${CONSUL_TAG_VERSION}...exiting."
  exit 1
fi

popd


## List created images

ts_log "\033[1m\033[33mImages generated\033[0m"

docker images --filter=reference="*/*:${DOCKER_REPOSITORY}"
