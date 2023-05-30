#!/usr/bin/env bash

CONFIGS="./service_mesh_configs"

rm -rf ${CONFIGS}

mkdir -p ${CONFIGS}
mkdir -p ${CONFIGS}/hashicups-db ${CONFIGS}/hashicups-api ${CONFIGS}/hashicups-frontend ${CONFIGS}/hashicups-nginx
mkdir -p ${CONFIGS}/global

##################
## Global
##################

echo "Create global proxy configuration"

tee ${CONFIGS}/global/config-global-proxy-default.hcl > /dev/null << EOF
Kind      = "proxy-defaults"
Name      = "global"
Config {
  protocol = "http"
}
EOF

tee ${CONFIGS}/global/config-global-proxy-default.json > /dev/null << EOF
{
    "Kind": "proxy-defaults",
    "Name": "global",
    "Config": {
      "Protocol": "http"
    }
}
EOF

##################
## Database
##################
SERVICE="hashicups-db"
NODE_NAME=${SERVICE}

echo "Create service ${SERVICE} configuration"

tee ${CONFIGS}/${SERVICE}/svc-${SERVICE}.hcl > /dev/null << EOF
## svc-${SERVICE}.hcl
service {
  name = "${SERVICE}"
  id = "${SERVICE}-1"
  tags = ["v1", "mesh"]
  port = 5432
  
  connect {
    sidecar_service {}
  }  
  
  check {
    id =  "check-${SERVICE}",
    name = "Product ${SERVICE} status check",
    service_id = "${SERVICE}-1",
    tcp  = "localhost:5432",
    interval = "1s",
    timeout = "1s"
  }
}
EOF

##################
## API
##################

SERVICE="hashicups-api"
NODE_NAME=${SERVICE}

echo "Create service ${SERVICE} configuration"

tee ${CONFIGS}/${SERVICE}/svc-${SERVICE}.hcl > /dev/null << EOF
## svc-${SERVICE}.hcl
service {
  name = "${SERVICE}"
  id = "${SERVICE}-1"
  tags = ["v1"]
  port = 8080
  
  connect {
    sidecar_service {
      proxy {
        upstreams = [
          {
            destination_name = "hashicups-db"
            local_bind_port = 5432
          }
        ]
      }
    }
  }

  checks =[ 
    {
      id =  "check-public-api",
      name = "Public API status check",
      service_id = "${SERVICE}-1",
      tcp  = "localhost:8081",
      interval = "1s",
      timeout = "1s"
    },
    {
      id =  "check-payments",
      name = "Payments status check",
      service_id = "${SERVICE}-1",
      tcp  = "${SERVICE}${FQDN_SUFFIX}:8080",
      interval = "1s",
      timeout = "1s"
    },
    {
      id =  "check-product-api",
      name = "Product API status check",
      service_id = "${SERVICE}-1",
      tcp  = "localhost:9090",
      interval = "1s",
      timeout = "1s"
    }
  ]
}
EOF

##################
## Frontend
##################
SERVICE="hashicups-frontend"
NODE_NAME=${SERVICE}

echo "Create service ${SERVICE} configuration"

tee ${CONFIGS}/${SERVICE}/svc-${SERVICE}.hcl > /dev/null << EOF
## svc-${SERVICE}.hcl
service {
  name = "${SERVICE}"
  id = "${SERVICE}-1"
  tags = ["v1"]
  port = 3000
  
  connect {
    sidecar_service {
      proxy {
        upstreams {
            destination_name = "hashicups-api"
            local_bind_address = "127.0.0.1"
            local_bind_port = 8081
        }
      }
    }
  }

  check {
    id =  "check-${SERVICE}",
    name = "Product ${SERVICE} status check",
    service_id = "${SERVICE}-1",
    tcp  = "localhost:3000",
    interval = "1s",
    timeout = "1s"
  }
}
EOF

##################
## NGINX
##################

SERVICE="hashicups-nginx"
NODE_NAME=${SERVICE}

echo "Create service ${SERVICE} configuration"

tee ${CONFIGS}/${SERVICE}/svc-${SERVICE}.hcl > /dev/null << EOF
## svc-${SERVICE}.hcl
service {
  name = "${SERVICE}"
  id = "${SERVICE}-1"
  tags = ["v1"]
  port = 80
  
  connect {
    sidecar_service {
      proxy {
        upstreams = [
          {
            destination_name = "hashicups-frontend"
            local_bind_port = 3000
          },
          {
            destination_name = "hashicups-api"
            local_bind_port = 8081
          }
        ]
      }
    }
  }

  check {
    id =  "check-${SERVICE}",
    name = "Product ${SERVICE} status check",
    service_id = "${SERVICE}-1",
    tcp  = "${SERVICE}${FQDN_SUFFIX}:80",
    interval = "1s",
    timeout = "1s"
  }
}
EOF


##################
## Intentions
##################

echo "Create intention configuration files"

tee ${CONFIGS}/global/intention-db.hcl > /dev/null << EOF
Kind = "service-intentions"
Name = "hashicups-db"
Sources = [
  {
    Name   = "hashicups-api"
    Action = "allow"
  }
]
EOF

tee ${CONFIGS}/global/intention-db.json > /dev/null << EOF
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


tee ${CONFIGS}/global/intention-api.hcl > /dev/null << EOF
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

tee ${CONFIGS}/global/intention-api.json > /dev/null << EOF
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


tee ${CONFIGS}/global/intention-frontend.hcl > /dev/null << EOF
Kind = "service-intentions"
Name = "hashicups-frontend"
Sources = [
  {
    Name   = "hashicups-nginx"
    Action = "allow"
  }
]
EOF

tee ${CONFIGS}/global/intention-frontend.json > /dev/null << EOF
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