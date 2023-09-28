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

# ++-----------------+
# || Variables       |
# ++-----------------+
OUTPUT_FOLDER=${OUTPUT_FOLDER:-"${STEP_ASSETS}"}

# | HASHICUPS SERVICE MAP
# |--------------------------------------------------
# | Service       | PORT    | Upstream
# | ------------- | ------- | -----------------------
# | database      | 5432    | []
# | api           | 8081    | [database]
# |   - payments  |   8080  |   []
# |   - product   |   9090  |  *[database]
# |   - public    |  *8081  |   [api.product, api.payments]
# | frontend      | 3000    | [api.public]
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

_log "Parameter Check"

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

_svc_name=${_services["$NODE_NAME.name"]}
_svc_port=${_services[$NODE_NAME.port]}
_svc_checks=${_services[$NODE_NAME.checks]}
_svc_upstreams=${_services[$NODE_NAME.upstreams]}

mkdir -p "${OUTPUT_FOLDER}${NODE_NAME}"

pushd "${OUTPUT_FOLDER}${NODE_NAME}"  > /dev/null 2>&1

mkdir -p "svc/service_discovery" "svc/service_mesh"

## Wrap service check definitiions
for i in `echo ${_svc_checks} | tr ',' '\n'`; do

  _CHECK_NAME=`echo $i | cut -d':' -f1`
  _CHECK_URL=`echo $i | cut -d':' -f2`:`echo $i | cut -d':' -f3`
    
  _CHECK_DEF=$(cat <<-END
    
  {
    id =  "check-${_CHECK_NAME}",
    name = "${_CHECK_NAME} status check",
    service_id = "${_svc_name}-1",
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
_log "Generating service definition for service discovery"

tee svc/service_discovery/svc-${_svc_name}.hcl > /dev/null << EOF
## -----------------------------
## svc-${_svc_name}.hcl
## -----------------------------
service {
  name = "${_svc_name}"
  id = "${_svc_name}-1"
  tags = ["v1"]
  port = ${_svc_port}
  ${_svc_token}

  ${_CHECKS_WRAPPER}
}
EOF

## Service Mesh File generation
_log "Generating service definition for service mesh"

tee svc/service_mesh/svc-${_svc_name}.hcl > /dev/null << EOF
## svc-${_svc_name}.hcl
service {
  name = "${_svc_name}"
  id = "${_svc_name}-1"
  port = ${_svc_port}
  ${_svc_token}
  connect {
    sidecar_service { ${_UPS_WRAPPER} }
  }  
  ${_CHECKS_WRAPPER}
}
EOF

popd > /dev/null 2>&1
