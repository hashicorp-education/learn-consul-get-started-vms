#!/usr/bin/env bash

# ++-----------------+
# || Functions       |
# ++-----------------+

## Prints a line on stdout prepended with date and time
_log() {
  echo -e "\033[1m["$(date +"%Y-%d-%d %H:%M:%S")"] -- ${@}\033[0m"
}

_header() {
  echo -e "\033[1m[$(date +'%Y-%d-%d %H:%M:%S')]\033[1m\033[33m [`basename $0`] - ${@}\033[0m"  
}

_log_err() {
  DEC_ERR="\033[1m\033[31m[ERROR] \033[0m\033[1m"
  _log "${DEC_ERR}${@}"  
}

_log_warn() {
  DEC_WARN="\033[1m\033[33m[WARN] \033[0m\033[1m"
  _log "${DEC_WARN}${@}"  
}

_get_latest_version () {
  PRODUCT=$1
  
  LATEST=`curl --silent https://releases.hashicorp.com/${PRODUCT} | \
  grep "${PRODUCT}" | \
  grep -v "+ent" | \
  grep -v "\-rc" | \
  grep -v "\-beta" | \
  grep -v "\-alpha"| \
  grep -Po "(?<=>${PRODUCT}_).*(?=<)" | \
  sort -rV | head -1`

  echo ${LATEST}

}

_get_arch () {

  _arch=`uname -m`

  if [[ "$_arch" == x86_64* ]]; then
    echo "amd64"
  elif [[ "$_arch" == aarch64 ]]; then
    echo "arm64"
  fi

}

# ++-----------------+
# || Variables       |
# ++-----------------+

VERSION=${CONSUL_ESM_VERSION:-"latest"}

OUTPUT_FOLDER="/home/${_USER}/bin"
PRODUCT="consul-esm"

# ++-----------------+
# || Begin           |
# ++-----------------+

## Creates binary bucker folder if it does not exist
mkdir -p ${OUTPUT_FOLDER}

## Check if binary alredy exists
if [ "${VERSION}" == "latest" ]; then
  _prod_version=`_get_latest_version ${PRODUCT}`
else
  _prod_version=${VERSION}
fi

if [ ! -z "${_prod_version}" ]; then
  if [ -f "${OUTPUT_FOLDER}/${PRODUCT}_${_prod_version}" ]; then
    _log "${PRODUCT} found at ${OUTPUT_FOLDER}/${PRODUCT}_${_prod_version}"
  else
    _log "${PRODUCT} not found...downloading."
    _prod_arch=`_get_arch`
    _tmp_folder=`mktemp -d`

    pushd ${_tmp_folder} > /dev/null 2>&1
    curl -L --silent https://releases.hashicorp.com/${PRODUCT}/${_prod_version}/${PRODUCT}_${_prod_version}_linux_${_prod_arch}.zip --output ${PRODUCT}_${_prod_version}_linux_${_prod_arch}.zip
    unzip ${PRODUCT}_${_prod_version}_linux_${_prod_arch}.zip
    popd > /dev/null 2>&1

    cp ${_tmp_folder}/${PRODUCT} ${OUTPUT_FOLDER}/${PRODUCT}_${_prod_version}

    rm -rf ${_tmp_folder}
  fi
else
  _log_err "Unable to find version for ${PRODUCT}. Skipping download"
fi

