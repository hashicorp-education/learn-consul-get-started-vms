#!/usr/bin/env bash

#
## Build images for AMD64

source "./variables.env"

B_ARCH="amd64"

LOCAL_REPO="local_${B_ARCH}"
REMOTE_REPO="danielehc"

BASE_IMAGE_TAG="base"
CONSUL_IMAGE_TAG="base-consul"

BASE_IMAGE="${LOCAL_REPO}/${BASE_IMAGE_TAG}-${B_ARCH}:latest"
BASE_CONSUL_IMAGE="${LOCAL_REPO}/${CONSUL_IMAGE_TAG}-${B_ARCH}:latest"

cd base

docker buildx build \
    --platform linux/${B_ARCH} \
    -t ${BASE_IMAGE} .

cd ../base-consul

docker buildx build \
    --platform linux/${B_ARCH} \
    --build-arg CONSUL_VERSION=${CONSUL_VERSION} \
    --build-arg ENVOY_VERSION=v${ENVOY_VERSION} \
    --build-arg BASE_IMAGE=${BASE_IMAGE} \
    -t ${BASE_CONSUL_IMAGE} .

cd ../hashicups-database

IMAGE_NAME="$(basename `pwd`)"
IMAGE_NAME="${LOCAL_REPO}/${IMAGE_NAME}-${B_ARCH}:latest"

docker buildx build \
    --platform linux/${B_ARCH} \
    --build-arg BASE_IMAGE="${BASE_CONSUL_IMAGE}" \
    -t ${IMAGE_NAME} .

cd ../hashicups-api

IMAGE_NAME="$(basename `pwd`)"
IMAGE_NAME="${LOCAL_REPO}/${IMAGE_NAME}-${B_ARCH}:latest"

docker buildx build \
    --platform linux/${B_ARCH} \
    --build-arg APP1_VERSION="${HC_API_PUBLIC_VERSION}" \
    --build-arg APP2_VERSION="${HC_API_PRODUCT_VERSION}" \
    --build-arg APP3_VERSION="${HC_API_PAYMENTS_VERSION}" \
    --build-arg BASE_IMAGE="${BASE_CONSUL_IMAGE}" \
    -t ${IMAGE_NAME} .

cd ../hashicups-frontend

IMAGE_NAME="$(basename `pwd`)"
IMAGE_NAME="${LOCAL_REPO}/${IMAGE_NAME}-${B_ARCH}:latest"

docker buildx build \
    --platform linux/${B_ARCH} \
    --build-arg APP_VERSION="" \
    --build-arg BASE_IMAGE="${BASE_CONSUL_IMAGE}" \
    -t ${IMAGE_NAME} .

cd ../hashicups-nginx

IMAGE_NAME="$(basename `pwd`)"
IMAGE_NAME="${LOCAL_REPO}/${IMAGE_NAME}-${B_ARCH}:latest"

docker buildx build \
    --platform linux/${B_ARCH} \
    --build-arg APP_VERSION="" \
    --build-arg BASE_IMAGE="${BASE_CONSUL_IMAGE}" \
    -t ${IMAGE_NAME} .