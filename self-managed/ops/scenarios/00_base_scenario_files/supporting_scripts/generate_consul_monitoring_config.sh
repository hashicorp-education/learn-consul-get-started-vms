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
  local _DATE="[$(date +"%Y-%d-%d %H:%M:%S")] "

  if [ ! "${PREPEND_DATE}" == true ]; then 
    _DATE=""
  fi

  if [ "${COLORED_OUTPUT}" == true ]; then 
    echo -e "\033[1m${_DATE}\033[1m\033[33m${_MSG}\033[0m"
  else
    echo -e "${_DATE}${_MSG}"
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
# || Variables       |
# ++-----------------+
OUTPUT_FOLDER=${OUTPUT_FOLDER:-"${STEP_ASSETS}"}

# ++-----------------+
# || Begin           |
# ++-----------------+

_header "- Generate configuration for Grafana agent"

_log "+ --------------------"
_log "| Parameter Check"
_log "+ --------------------"
_log_warn "Script is running with the following values:"
_log_warn "----------"
_log_warn "PROMETHEUS_URI = ${PROMETHEUS_URI}"
_log_warn "LOKI_URI = ${LOKI_URI}"
_log_warn "----------"

_log_warn "Generated configuration will be placed under:"
_log_warn "OUTPUT_FOLDER = ${OUTPUT_FOLDER:-"${STEP_ASSETS}"}"
_log_warn "----------"

_log "Parameter Check"

[ -z "$OUTPUT_FOLDER" ] && _log_err "Mandatory parameter: OUTPUT_FOLDER not set."      && exit 1
[ -z "$PROMETHEUS_URI" ] && _log_err "Mandatory parameter: PROMETHEUS_URI not set."      && exit 1
[ -z "$LOKI_URI" ] && _log_err "Mandatory parameter: LOKI_URI not set."      && exit 1

rm -rf ${OUTPUT_FOLDER}monitoring

mkdir -p "${OUTPUT_FOLDER}monitoring"

_log ""
_log "+ --------------------"
_log "| Generate Grafana Agent configuration"
_log "+ --------------------"


NODE="consul-server-0"

_log "Generating configuration for ${NODE}"

tee ${OUTPUT_FOLDER}monitoring/grafana-agent-${NODE}.yaml > /dev/null << EOF
server:
  log_level: debug

metrics:
  global:
    scrape_interval: 60s
    remote_write:
    - url: http://${PROMETHEUS_URI}:9009/api/v1/push
  configs:
  - name: default
    scrape_configs:
    - job_name: consul-server
      metrics_path: '/v1/agent/metrics'
      static_configs:
        - targets: ['127.0.0.1:8500']

logs:
  configs:
  - name: default
    clients:
      - url: http://${LOKI_URI}:3100/loki/api/v1/push
    positions:
      filename: /tmp/positions.yaml
    scrape_configs:
     - job_name: consul-server
       static_configs:
       - targets: 
           - localhost
         labels:
           job: logs
           host: ${NODE}
           __path__: /tmp/*.log
EOF

NODE="hashicups-db-0"

_log "Generating configuration for ${NODE}"

tee ${OUTPUT_FOLDER}monitoring/grafana-agent-${NODE}.yaml > /dev/null << EOF
server:
  log_level: debug

metrics:
  global:
    scrape_interval: 60s
    remote_write:
    - url: http://${PROMETHEUS_URI}:9009/api/v1/push
  configs:
  - name: default
    scrape_configs:
    - job_name: ${NODE}
      metrics_path: '/stats/prometheus'
      static_configs:
        - targets: ['127.0.0.1:19000']
    - job_name: consul-agent
      metrics_path: '/v1/agent/metrics'
      static_configs:
        - targets: ['127.0.0.1:8500']

logs:
  configs:
  - name: default
    clients:
      - url: http://${LOKI_URI}:3100/loki/api/v1/push
    positions:
      filename: /tmp/positions.yaml
    scrape_configs:
     - job_name: service-mesh-apps
       static_configs:
       - targets: 
           - localhost
         labels:
           job: logs
           host: ${NODE}
           __path__: /tmp/*.log
EOF

NODE="hashicups-api-0"

_log "Generating configuration for ${NODE}"

tee ${OUTPUT_FOLDER}monitoring/grafana-agent-${NODE}.yaml > /dev/null << EOF
server:
  log_level: debug

metrics:
  global:
    scrape_interval: 60s
    remote_write:
    - url: http://${PROMETHEUS_URI}:9009/api/v1/push
  configs:
  - name: default
    scrape_configs:
    - job_name: ${NODE}
      metrics_path: '/stats/prometheus'
      static_configs:
        - targets: ['127.0.0.1:19000']
    - job_name: consul-agent
      metrics_path: '/v1/agent/metrics'
      static_configs:
        - targets: ['127.0.0.1:8500']

logs:
  configs:
  - name: default
    clients:
      - url: http://${LOKI_URI}:3100/loki/api/v1/push
    positions:
      filename: /tmp/positions.yaml
    scrape_configs:
     - job_name: service-mesh-apps
       static_configs:
       - targets: 
           - localhost
         labels:
           job: logs
           host: ${NODE}
           __path__: /tmp/*.log
EOF

NODE="hashicups-frontend-0"

_log "Generating configuration for ${NODE}"

tee ${OUTPUT_FOLDER}monitoring/grafana-agent-${NODE}.yaml > /dev/null << EOF
server:
  log_level: debug

metrics:
  global:
    scrape_interval: 60s
    remote_write:
    - url: http://${PROMETHEUS_URI}:9009/api/v1/push
  configs:
  - name: default
    scrape_configs:
    - job_name: ${NODE}
      metrics_path: '/stats/prometheus'
      static_configs:
        - targets: ['127.0.0.1:19000']
    - job_name: consul-agent
      metrics_path: '/v1/agent/metrics'
      static_configs:
        - targets: ['127.0.0.1:8500']

logs:
  configs:
  - name: default
    clients:
      - url: http://${LOKI_URI}:3100/loki/api/v1/push
    positions:
      filename: /tmp/positions.yaml
    scrape_configs:
     - job_name: service-mesh-apps
       static_configs:
       - targets: 
           - localhost
         labels:
           job: logs
           host: ${NODE}
           __path__: /tmp/*.log
EOF

NODE="hashicups-nginx-0"

_log "Generating configuration for ${NODE}"

tee ${OUTPUT_FOLDER}monitoring/grafana-agent-${NODE}.yaml > /dev/null << EOF
server:
  log_level: debug

metrics:
  global:
    scrape_interval: 60s
    remote_write:
    - url: http://${PROMETHEUS_URI}:9009/api/v1/push
  configs:
  - name: default
    scrape_configs:
    - job_name: ${NODE}
      metrics_path: '/stats/prometheus'
      static_configs:
        - targets: ['127.0.0.1:19000']
    - job_name: consul-agent
      metrics_path: '/v1/agent/metrics'
      static_configs:
        - targets: ['127.0.0.1:8500']

logs:
  configs:
  - name: default
    clients:
      - url: http://${LOKI_URI}:3100/loki/api/v1/push
    positions:
      filename: /tmp/positions.yaml
    scrape_configs:
     - job_name: service-mesh-apps
       static_configs:
       - targets: 
           - localhost
         labels:
           job: logs
           host: ${NODE}
           __path__: /tmp/*.log
EOF

NODE="gateway-api-0"

_log "Generating configuration for ${NODE}"

tee ${OUTPUT_FOLDER}monitoring/grafana-agent-${NODE}.yaml > /dev/null << EOF
server:
  log_level: debug

metrics:
  global:
    scrape_interval: 60s
    remote_write:
    - url: http://${PROMETHEUS_URI}:9009/api/v1/push
  configs:
  - name: default
    scrape_configs:
    - job_name: ${NODE}
      metrics_path: '/stats/prometheus'
      static_configs:
        - targets: ['127.0.0.1:19000']
    - job_name: consul-agent
      metrics_path: '/v1/agent/metrics'
      static_configs:
        - targets: ['127.0.0.1:8500']

logs:
  configs:
  - name: default
    clients:
      - url: http://${LOKI_URI}:3100/loki/api/v1/push
    positions:
      filename: /tmp/positions.yaml
    scrape_configs:
     - job_name: service-mesh-apps
       static_configs:
       - targets: 
           - localhost
         labels:
           job: logs
           host: ${NODE}
           __path__: /tmp/*.log
EOF


