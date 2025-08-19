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

# +--------------------+ #
# | BUILD BASE         | #
# +--------------------+ #

## Enter Image folder
pushd ${BUILD_DIR}base > /dev/null 2>&1

# +--------------------+ #
# | GENERATE SSL CERTS | #
# +--------------------+ #

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

  ## Enter certs folder
  pushd ${KEYS_DIR} > /dev/null 2>&1

  ## Generate SSH keys for containers
  ssh-keygen -t rsa -b 4096 -f ./id_rsa -N ""

  ## Exit certs folder
  popd > /dev/null 2>&1
fi

ts_log "Building \033[1m\033[33m${DOCKER_REPOSITORY}/${DOCKER_BASE_IMAGE}\033[0m"

IMAGE_TAG="${DOCKER_REPOSITORY}/${DOCKER_BASE_IMAGE}:latest"
LATEST_TAG="-t ${DOCKER_REPOSITORY}/${DOCKER_BASE_IMAGE}:latest"
LS_TAG="-t ${DOCKER_REPOSITORY}/${DOCKER_BASE_IMAGE}:${DOCKER_REPOSITORY}"

## Build Docker image
DOCKER_BUILDKIT=1 docker build \
  -t "${IMAGE_TAG}" ${LATEST_TAG} ${LS_TAG} . > /dev/null 2>&1

if [ $? != 0 ]; then
  ts_log "\033[1m\033[31m[ERROR]\033[0m - Failed build for ${DOCKER_REPOSITORY}/${DOCKER_BASE_IMAGE}:latest...exiting."
  exit 1
fi

## Exit Image folder
popd > /dev/null 2>&1

# +--------------------+ #
# | BUILD BASE_CONSUL  | #
# +--------------------+ #

## Enter Image folder
pushd ${BUILD_DIR}base-consul > /dev/null 2>&1

ts_log "Building \033[1m\033[33m${DOCKER_REPOSITORY}/${DOCKER_BASE_CONSUL}\033[0m"

IMAGE_TAG="${DOCKER_REPOSITORY}/${DOCKER_BASE_CONSUL}:v${CONSUL_VERSION}"
LATEST_TAG="-t ${DOCKER_REPOSITORY}/${DOCKER_BASE_CONSUL}:latest"
LS_TAG="-t ${DOCKER_REPOSITORY}/${DOCKER_BASE_CONSUL}:${DOCKER_REPOSITORY}"

ENVOY_NEW_VERSION=`echo ${ENVOY_VERSION} | sed 's/.x/-latest/'`

## Build Docker image
DOCKER_BUILDKIT=1 docker build \
  --build-arg CONSUL_VERSION=${CONSUL_VERSION} \
  --build-arg ENVOY_VERSION=v${ENVOY_NEW_VERSION} \
  --build-arg BASE_IMAGE="${DOCKER_REPOSITORY}/${DOCKER_BASE_IMAGE}:latest" \
  -t "${IMAGE_TAG}" ${LATEST_TAG} ${LS_TAG} . > /dev/null 2>&1

if [ $? != 0 ]; then
  ts_log "\033[1m\033[31m[ERROR]\033[0m - Failed build for ${DOCKER_REPOSITORY}/${DOCKER_BASE_CONSUL}...exiting."
  exit 1
fi

## Exit Image folder
popd > /dev/null 2>&1

# +--------------------+ #
# | BUILD HASHICUPS-*  | #
# +--------------------+ #

# +--------------------+ #
# | DATABASE           | #
# +--------------------+ #

IMAGE_NAME="hashicups-database"
pushd ${IMAGE_NAME} > /dev/null 2>&1

ts_log "Building \033[1m\033[33m${DOCKER_REPOSITORY}/${IMAGE_NAME}\033[0m"

IMAGE_TAG="${DOCKER_REPOSITORY}/${IMAGE_NAME}:v${CONSUL_VERSION}"
LATEST_TAG="-t ${DOCKER_REPOSITORY}/${IMAGE_NAME}:latest"
LS_TAG="-t ${DOCKER_REPOSITORY}/${IMAGE_NAME}:${DOCKER_REPOSITORY}"

## Build Docker image
DOCKER_BUILDKIT=1 docker build \
  --build-arg BASE_IMAGE="${DOCKER_REPOSITORY}/${DOCKER_BASE_CONSUL}:latest" \
  -t "${IMAGE_TAG}" ${LATEST_TAG} ${LS_TAG} . > /dev/null 2>&1 &

if [ $? != 0 ]; then
  ts_log "\033[1m\033[31m[ERROR]\033[0m - Failed build for ${DOCKER_REPOSITORY}/${IMAGE_NAME}...exiting."
  exit 1
fi

popd > /dev/null 2>&1

# ==============================================================================
# ==============================================================================

# +--------------------+ #
# | API                | #
# +--------------------+ #

IMAGE_NAME="hashicups-api"
pushd ${IMAGE_NAME} > /dev/null 2>&1

ts_log "Building \033[1m\033[33m${DOCKER_REPOSITORY}/${IMAGE_NAME}\033[0m"

IMAGE_TAG="${DOCKER_REPOSITORY}/${IMAGE_NAME}:v${CONSUL_VERSION}"
LATEST_TAG="-t ${DOCKER_REPOSITORY}/${IMAGE_NAME}:latest"
LS_TAG="-t ${DOCKER_REPOSITORY}/${IMAGE_NAME}:${DOCKER_REPOSITORY}"

## Build Docker image
DOCKER_BUILDKIT=1 docker build \
  --build-arg APP1_VERSION="${HC_API_PUBLIC_VERSION}" \
  --build-arg APP2_VERSION="${HC_API_PRODUCT_VERSION}" \
  --build-arg APP3_VERSION="${HC_API_PAYMENTS_VERSION}" \
  --build-arg BASE_IMAGE="${DOCKER_REPOSITORY}/${DOCKER_BASE_CONSUL}:latest" \
  -t "${IMAGE_TAG}" ${LATEST_TAG} ${LS_TAG} . > /dev/null 2>&1 &

if [ $? != 0 ]; then
  ts_log "\033[1m\033[31m[ERROR]\033[0m - Failed build for ${DOCKER_REPOSITORY}/${IMAGE_NAME}...exiting."
  exit 1
fi

popd > /dev/null 2>&1

# ==============================================================================
# ==============================================================================

# +--------------------+ #
# | FRONTEND           | #
# +--------------------+ #

IMAGE_NAME="hashicups-frontend"
pushd ${IMAGE_NAME} > /dev/null 2>&1

ts_log "Building \033[1m\033[33m${DOCKER_REPOSITORY}/${IMAGE_NAME}\033[0m"

IMAGE_TAG="${DOCKER_REPOSITORY}/${IMAGE_NAME}:v${CONSUL_VERSION}"
LATEST_TAG="-t ${DOCKER_REPOSITORY}/${IMAGE_NAME}:latest"
LS_TAG="-t ${DOCKER_REPOSITORY}/${IMAGE_NAME}:${DOCKER_REPOSITORY}"

## Build Docker image
DOCKER_BUILDKIT=1 docker build \
  --build-arg APP_VERSION="" \
  --build-arg BASE_IMAGE="${DOCKER_REPOSITORY}/${DOCKER_BASE_CONSUL}:latest" \
  -t "${IMAGE_TAG}" ${LATEST_TAG} ${LS_TAG} . > /dev/null 2>&1 &

if [ $? != 0 ]; then
  ts_log "\033[1m\033[31m[ERROR]\033[0m - Failed build for ${DOCKER_REPOSITORY}/${IMAGE_NAME}...exiting."
  exit 1
fi

popd > /dev/null 2>&1

# ==============================================================================
# ==============================================================================

# +--------------------+ #
# | NGINX              | #
# +--------------------+ #

IMAGE_NAME="hashicups-nginx"
pushd ${IMAGE_NAME} > /dev/null 2>&1

ts_log "Building \033[1m\033[33m${DOCKER_REPOSITORY}/${IMAGE_NAME}\033[0m"

IMAGE_TAG="${DOCKER_REPOSITORY}/${IMAGE_NAME}:v${CONSUL_VERSION}"
LATEST_TAG="-t ${DOCKER_REPOSITORY}/${IMAGE_NAME}:latest"
LS_TAG="-t ${DOCKER_REPOSITORY}/${IMAGE_NAME}:${DOCKER_REPOSITORY}"

## Build Docker image
DOCKER_BUILDKIT=1 docker build \
  --build-arg APP_VERSION="" \
  --build-arg BASE_IMAGE="${DOCKER_REPOSITORY}/${DOCKER_BASE_CONSUL}:latest" \
  -t "${IMAGE_TAG}" ${LATEST_TAG} ${LS_TAG} . > /dev/null 2>&1 &

if [ $? != 0 ]; then
  ts_log "\033[1m\033[31m[ERROR]\033[0m - Failed build for ${DOCKER_REPOSITORY}/${IMAGE_NAME}...exiting."
  exit 1
fi

popd > /dev/null 2>&1

wait

# +---------------------+ #
# | LIST CREATED IMAGES | #
# +---------------------+ #

## List created images
ts_log "\033[1m\033[33mImages generated\033[0m"
docker images --filter=reference="*/*:${DOCKER_REPOSITORY}"

## Information about Applications installed
ts_log "\033[1m\033[33mVersion Info:\033[0m"
echo -e "- \033[1m\033[31m[Consul]\033[0m: ${CONSUL_VERSION}"
echo -e "- \033[1m\033[35m[Envoy]\033[0m: ${ENVOY_VERSION}"

