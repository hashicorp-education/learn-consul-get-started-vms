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
[ -z "$PROMETHEUS_URI" ] && _log_err "Mandatory parameter: PROMETHEUS_URI not set."      && exit 1
[ -z "$LOKI_URI" ] && _log_err "Mandatory parameter: LOKI_URI not set."      && exit 1

rm -rf ${OUTPUT_FOLDER}monitoring

mkdir -p "${OUTPUT_FOLDER}monitoring"

##################
## Monitoring
##################

_log "Generating Grafana Agent configuration"

NODE="consul-server-0"

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

NODE="hashicups-db"

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

NODE="hashicups-api"

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

NODE="hashicups-frontend"

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

NODE="hashicups-nginx"

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

NODE="gateway-api"

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


