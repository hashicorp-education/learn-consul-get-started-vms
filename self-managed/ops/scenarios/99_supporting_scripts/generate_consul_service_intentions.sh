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

# ++-----------------+
# || Begin           |
# ++-----------------+

# _header "[${NODE_NAME}]"

_log "Parameter Check"

[ -z "$OUTPUT_FOLDER" ] && _log_err "Mandatory parameter: OUTPUT_FOLDER not set."      && exit 1

rm -rf ${OUTPUT_FOLDER}global

mkdir -p "${OUTPUT_FOLDER}global"


##################
## Global
##################

_log "Create global proxy configuration"

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



##################
## Intentions
##################

_log "Create intention configuration files"

tee ${OUTPUT_FOLDER}global/intention-allow-all.hcl > /dev/null << EOF
Kind = "service-intentions"
Name = "*"
Sources = [
  {
    Name   = "*"
    Action = "allow"
  }
]
EOF

tee ${OUTPUT_FOLDER}global/intention-allow-all.json > /dev/null << EOF
{
  "Kind": "service-intentions",
  "Name": "*",
  "Sources": [
    {
      "Action": "allow",
      "Name": "*"
    }
  ]
}
EOF


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