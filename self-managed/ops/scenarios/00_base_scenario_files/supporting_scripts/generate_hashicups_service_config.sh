#!/usr/bin/env bash

# ++-----------------+
# || Functions       |
# ++-----------------+
## Prints a line on stdout prepended with date and time

_log() {

  local _MSG="${@}"

  if [ "${PREPEND_DATE}" == true ]; then 
    _MSG="[$(date +"%Y-%d-%d %H:%M:%S")] -- ""${_MSG}"
  fi

  if [ "${COLORED_OUTPUT}" == true ]; then 
    echo -e "\033[1m${_MSG}\033[0m"
  else
    echo -e "${_MSG}"
  fi
}

_header() {

  local _MSG="[`basename $0`] - ${@}"
  local _DATE="[$(date +"%Y-%d-%d %H:%M:%S")]"

  if [ ! "${PREPEND_DATE}" == true ]; then 
    _DATE=""
  fi

  if [ "${COLORED_OUTPUT}" == true ]; then 
    echo -e "\033[1m${_DATE}\033[1m\033[33m ${_MSG}\033[0m"
  else
    echo -e "${_DATE} ${_MSG}"
  fi
}

_log_err() {

  if [ "${COLORED_OUTPUT}" == true ]; then 
    DEC_ERR="\033[1m\033[31m[ERROR] \033[0m\033[1m"
  else
    DEC_ERR="[ERROR] "
  fi

  _log "${DEC_ERR}${@}"  
}

_log_warn() {
  
  if [ "${COLORED_OUTPUT}" == true ]; then 
    DEC_WARN="\033[1m\033[33m[WARN] \033[0m\033[1m"
  else
    DEC_WARN="[WARN] "
  fi
  
  _log "${DEC_WARN}${@}"  
}

# ++-----------------+
# || Parameters      |
# ++-----------------+

## If colored output is not disabled by default the logs are colored.
COLORED_OUTPUT=${COLORED_OUTPUT:-"true"}
PREPEND_DATE=${PREPEND_DATE:-"true"}

OUTPUT_FOLDER=${OUTPUT_FOLDER:-"${STEP_ASSETS}"}

SVC_TAGS=${SVC_TAGS:-'"v1"'}

# | HASHICUPS SERVICE MAP
# |--------------------------------------------------
# | Service       | PORT    | Upstream
# | ------------- | ------- | -----------------------
# | database      | 5432    | []
# | api           | 8081    | [database]
# |   - payments  |   8080  |   []
# |   - product   |   9090  |  *[database]
# |   - public    |  *8081  |   [api.product, api.payments]
# | frontend      | 3000    | []
# | nginx         | 80      | [frontend, api.public]

declare -A _services

_services["hashicups-db.name"]="hashicups-db"
_services["hashicups-db.port"]="5432"
_services["hashicups-db.checks"]="hashicups-db:localhost:5432"
_services["hashicups-db.upstreams"]=""

_services["hashicups-api.name"]="hashicups-api"
_services["hashicups-api.port"]="8081"
_services["hashicups-api.checks"]="hashicups-api.public:localhost:8081,hashicups-api.product:localhost:9090,hashicups-api.payments:localhost:8080"
_services["hashicups-api.upstreams"]="hashicups-db:5432"

_services["hashicups-frontend.name"]="hashicups-frontend"
_services["hashicups-frontend.port"]="3000"
_services["hashicups-frontend.checks"]="hashicups-frontend:localhost:3000"
_services["hashicups-frontend.upstreams"]=""

_services["hashicups-nginx.name"]="hashicups-nginx"
_services["hashicups-nginx.port"]="80"
_services["hashicups-nginx.checks"]="hashicups-nginx:localhost:80"
_services["hashicups-nginx.upstreams"]="hashicups-frontend:3000,hashicups-api:8081"

# hashicups-db=("hashicups-db" "5432" "hashicups-db:localhost:5432" " ")
# hashicups-api=("hashicups-api" "8081" "hashicups-api.public:localhost:8081,hashicups-api.product:localhost:9090,hashicups-api.payments:localhost:8080"  "hashicups-db:5432")
# hashicups-frontend=("hashicups-frontend" "3000" "hashicups-frontend:localhost:3000" "hashicups-api:8081")
# hashicups-nginx=("hashicups-nginx" "80" "hashicups-nginx:localhost:80" "hashicups-frontend:3000,hashicups-api:8081")

# ++-----------------+
# || Begin           |
# ++-----------------+

_header "[${NODE_NAME}]"

_log ""
_log "+ --------------------"
_log "| Parameter Check"
_log "+ --------------------"

_log " - Check if a service token is defined"

## If a variable CONSUL_AGENT_TOKEN is set includes the token parameter to the 
## service configuration
if [ ! -z "${CONSUL_AGENT_TOKEN}" ]; then
  _svc_token="token = \"${CONSUL_AGENT_TOKEN}\""
fi

## If a variable _agent_token is set includes the token parameter to the 
## service configuration
if [ ! -z "${_agent_token}" ]; then
  _svc_token="token = \"${_agent_token}\""
fi

[ -z "$OUTPUT_FOLDER" ] && _log_err "Mandatory parameter: OUTPUT_FOLDER not set."      && exit 1
[ -z "$NODE_NAME" ]     && _log_err "Mandatory parameter: NODE_NAME not set."          && exit 1

_log ""
_log "+ --------------------"
_log "| Generate service configuration files for ${NODE_NAME}"
_log "+ --------------------"

_log " - Get service details"

## Example:
## NODE_NAME    = hashicups-db-3
## SERVICE_NAME = hashicups-db
## SERVICE_ID   = 3

SERVICE_NAME=`echo ${NODE_NAME} | awk '{split($0,a,"-"); print a[1]"-"a[2]}'`
SERVICE_ID=`echo ${NODE_NAME} | awk '{split($0,a,"-"); print a[3]}'`

# _log_warn "Service splitting - ${SERVICE_NAME} + ${SERVICE_ID}"
# exit 0

_svc_name=${_services["$SERVICE_NAME.name"]}
_svc_port=${_services[$SERVICE_NAME.port]}
_svc_checks=${_services[$SERVICE_NAME.checks]}
_svc_upstreams=${_services[$SERVICE_NAME.upstreams]}

_log " - Prepare folders"

mkdir -p "${OUTPUT_FOLDER}${NODE_NAME}"

pushd "${OUTPUT_FOLDER}${NODE_NAME}"  > /dev/null 2>&1

mkdir -p "svc/service_discovery" "svc/service_mesh"

_log " - Generate checks definition"

## Wrap service check definitiions
for i in `echo ${_svc_checks} | tr ',' '\n'`; do

  _CHECK_NAME=`echo $i | cut -d':' -f1`
  _CHECK_URL=`echo $i | cut -d':' -f2`:`echo $i | cut -d':' -f3`
    
  _CHECK_DEF=$(cat <<-END
    
  {
    id =  "check-${_CHECK_NAME}",
    name = "${_CHECK_NAME} status check",
    service_id = "${_svc_name}-${SERVICE_ID}",
    tcp  = "${_CHECK_URL}",
    interval = "5s",
    timeout = "5s"
  }
END
)
    if [ ! -z "${_SERVICE_DEF_CHECK}" -a "${_SERVICE_DEF_CHECK}"!=" " ]; then
      _SERVICE_DEF_CHECK="${_SERVICE_DEF_CHECK},${_CHECK_DEF}"
      _MULTI_CHECK=true
    else
      _SERVICE_DEF_CHECK="${_CHECK_DEF}"
    fi

done

# echo -e ${_SERVICE_DEF_CHECK} | wc -l

if [ "${_MULTI_CHECK}" == true ]; then
    _CHECKS_WRAPPER="checks =[${_SERVICE_DEF_CHECK}]"
else
    _CHECKS_WRAPPER="check ${_SERVICE_DEF_CHECK}"
fi

## Wrap upstreams definitions
for i in `echo ${_svc_upstreams} | tr ',' '\n'`; do

  _UPS_NAME=`echo $i | cut -d':' -f1`
  _UPS_PORT=`echo $i | cut -d':' -f2`
    
  _UPS_DEF=$(cat <<-END
{
              destination_name = "${_UPS_NAME}"
              local_bind_port = ${_UPS_PORT}
            }
END
)
  
  if [ ! -z "${_SERVICE_DEF_UPS}" -a "${_SERVICE_DEF_UPS}"!=" " ]; then
    _SERVICE_DEF_UPS="${_SERVICE_DEF_UPS},
            ${_UPS_DEF}"
    _MULTI_UPS=true
  else
    _SERVICE_DEF_UPS="${_UPS_DEF}"
    _MULTI_UPS=true
  fi

done

if [ "${_MULTI_UPS}" == true ]; then

    # One or more upstreams
    _UPS_WRAPPER=$(cat <<-END
        
        proxy {
          upstreams = [
            ${_SERVICE_DEF_UPS}
          ]
        }
    
END
)

fi

## Service Discovery File generation
_log " - Generate service definition for service discovery"

tee svc/service_discovery/svc-${_svc_name}.hcl > /dev/null << EOF
## -----------------------------
## svc-${_svc_name}.hcl
## -----------------------------
service {
  name = "${_svc_name}"
  id = "${_svc_name}-${SERVICE_ID}"
  tags = [ ${SVC_TAGS} ]
  port = ${_svc_port}
  ${_svc_token}

  ${_CHECKS_WRAPPER}
}
EOF

## Service Mesh File generation
_log " - Generate service definition for service mesh"

tee svc/service_mesh/svc-${_svc_name}.hcl > /dev/null << EOF
## svc-${_svc_name}.hcl
service {
  name = "${_svc_name}"
  id = "${_svc_name}-${SERVICE_ID}"
  tags = [ ${SVC_TAGS} ]
  port = ${_svc_port}
  ${_svc_token}
  connect {
    sidecar_service { ${_UPS_WRAPPER} }
  }  
  ${_CHECKS_WRAPPER}
}
EOF

popd > /dev/null 2>&1
