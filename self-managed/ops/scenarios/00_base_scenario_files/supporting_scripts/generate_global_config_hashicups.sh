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

# ++-----------------+
# || Begin           |
# ++-----------------+

_header " - Generate configuration for HashiCups application"

_log ""
_log "+ --------------------"
_log "| Parameter Check"
_log "+ --------------------"
_log_warn "Generated configuration will be placed under:"
_log_warn "OUTPUT_FOLDER = ${OUTPUT_FOLDER:-"${STEP_ASSETS}"}"
_log_warn "----------"

[ -z "$OUTPUT_FOLDER" ] && _log_err "Mandatory parameter: OUTPUT_FOLDER not set."      && exit 1

_log ""
_log "+ --------------------"
_log "| Prepare folder"
_log "+ --------------------"

_log " - Cleaning folder from pre-existing files"
rm -rf ${OUTPUT_FOLDER}global

_log " - Generate scenario config folders."
mkdir -p "${OUTPUT_FOLDER}global"

_log ""
_log "+ --------------------"
_log "| Create global configuration definition files"
_log "+ --------------------"

_log " - Create global proxy configuration"

tee ${OUTPUT_FOLDER}global/config-global-proxy-default.hcl > /dev/null << EOF
Kind      = "proxy-defaults"
Name      = "global"
Config {
  protocol = "http"
}
EOF

tee ${OUTPUT_FOLDER}global/config-global-proxy-default.json > /dev/null << EOF
{
    "Kind": "proxy-defaults",
    "Name": "global",
    "Config": {
      "Protocol": "http"
    }
}
EOF

_log " - Create hashicups-db service defaults configutation"

tee ${OUTPUT_FOLDER}global/config-hashicups-db-service-defaults.hcl > /dev/null << EOF
Kind      = "service-defaults"
Name      = "hashicups-db"
Protocol  = "tcp"
EOF

tee ${OUTPUT_FOLDER}global/config-hashicups-db-service-defaults.json > /dev/null << EOF
{
    "Kind": "service-defaults",
    "Name": "hashicups-db",
    "Protocol": "tcp"
}
EOF


_log ""
_log "+ --------------------"
_log "| Create intention definition files"
_log "+ --------------------"

# _log "Create intention configuration files"

# tee ${OUTPUT_FOLDER}global/intention-allow-all.hcl > /dev/null << EOF
# Kind = "service-intentions"
# Name = "*"
# Sources = [
#   {
#     Name   = "*"
#     Action = "allow"
#   }
# ]
# EOF

# tee ${OUTPUT_FOLDER}global/intention-allow-all.json > /dev/null << EOF
# {
#   "Kind": "service-intentions",
#   "Name": "*",
#   "Sources": [
#     {
#       "Action": "allow",
#       "Name": "*"
#     }
#   ]
# }
# EOF


_log " - Intentions for Database service"

tee ${OUTPUT_FOLDER}global/intention-db.hcl > /dev/null << EOF
Kind = "service-intentions"
Name = "hashicups-db"
Sources = [
  {
    Name   = "hashicups-api"
    Action = "allow"
  }
]
EOF

tee ${OUTPUT_FOLDER}global/intention-db.json > /dev/null << EOF
{
  "Kind": "service-intentions",
  "Name": "hashicups-db",
  "Sources": [
    {
      "Action": "allow",
      "Name": "hashicups-api"
    }
  ]
}
EOF

_log " - Intentions for API service"

tee ${OUTPUT_FOLDER}global/intention-api.hcl > /dev/null << EOF
Kind = "service-intentions"
Name = "hashicups-api"
Sources = [
  {
    Name   = "hashicups-frontend"
    Action = "allow"
  },
  {
    Name   = "hashicups-nginx"
    Action = "allow"
  }
]
EOF

tee ${OUTPUT_FOLDER}global/intention-api.json > /dev/null << EOF
{
  "Kind": "service-intentions",
  "Name": "hashicups-api",
  "Sources": [
    {
      "Action": "allow",
      "Name": "hashicups-frontend"
    },
    {
      "Action": "allow",
      "Name": "hashicups-nginx"
    }
  ]
}
EOF

_log " - Intentions for Frontend service"

tee ${OUTPUT_FOLDER}global/intention-frontend.hcl > /dev/null << EOF
Kind = "service-intentions"
Name = "hashicups-frontend"
Sources = [
  {
    Name   = "hashicups-nginx"
    Action = "allow"
  }
]
EOF

tee ${OUTPUT_FOLDER}global/intention-frontend.json > /dev/null << EOF
{
  "Kind": "service-intentions",
  "Name": "hashicups-frontend",
  "Sources": [
    {
      "Action": "allow",
      "Name": "hashicups-nginx"
    }
  ]
}
EOF