# Getting started with Consul on VMs

This repository is intended to be used as support for the
[Consul get started on VMs](https://learn.hashicorp.com/collections/consul/get-started-vms)
tutorial collection.

## generate_consul_server_config.sh

Generates a Consul server configuration. The configuration is secured using:
* Gossip Encryption
* TLS encryption
* ACL enabled with default policy `deny`

### Prerequisites

* The scripts requires Consul binary available on the node
* The following environment variables can be set to tune the configuration:

| Variable | Default | Description |
| --- | --- | --- |
| DATACENTER        | `dc1` | [datacenter name]() |
| DOMAIN            | `consul` | [datacenter domain](https://www.consul.io/docs/agent/config/cli-flags#_domain) |
| CONSUL_DATA_DIR   | `/etc/consul/data` | [location for Consul data persistence](https://www.consul.io/docs/agent/config/cli-flags#_data_dir) |
| CONSUL_CONFIG_DIR | `/etc/consul/config` | [location for Consul configuration](https://www.consul.io/docs/agent/config/cli-flags#_config_dir). **Files will be stored in this folder.** |
| DNS_RECURSOR      | `1.1.1.1` | [recursors for DNS configuration](https://www.consul.io/docs/agent/config/config-files#recursors) |
| HTTPS_PORT        | `8443` | [port for HTTPS service](https://www.consul.io/docs/agent/config/config-files#https_port) |
| DNS_PORT          | `8600` | [port for DNS service](https://www.consul.io/docs/agent/config/config-files#dns_port) |


### Usage

```shell
./generate_consul_server_config.sh
```

The script will generate the following files:

```plaintest
agent-gossip-encryption.hcl
agent-server-acl.hcl
agent-server-secure.hcl
agent-server-specific.hcl
agent-server-tls.hcl
consul-agent-ca-key.pem
consul-agent-ca.pem
dc1-server-consul-0-key.pem
dc1-server-consul-0.pem
```

## generate_consul_client_config.sh

Generates Consul client configuration for the HashiCups application.
The output can be used as an example and you can tune it to adapt for your system.

### Prerequisites

* The scripts requires Consul binary available on the node
* The script requires the Gossip encryption configuration and the CA certificate for Consul datacenter
* The following environment variables can be set to tune the configuration:

| Variable | Default | Description |
| --- | --- | --- |
| DATACENTER        | `dc1` | [datacenter name]() |
| DOMAIN            | `consul` | [datacenter domain](https://www.consul.io/docs/agent/config/cli-flags#_domain) |
| CONSUL_DATA_DIR   | `/etc/consul/data` | [location for Consul data persistence](https://www.consul.io/docs/agent/config/cli-flags#_data_dir) |
| CONSUL_CONFIG_DIR | `/etc/consul/config` | [location for Consul configuration](https://www.consul.io/docs/agent/config/cli-flags#_config_dir). **Files will be stored in this folder.** |
| DNS_RECURSOR      | `1.1.1.1` | [recursors for DNS configuration](https://www.consul.io/docs/agent/config/config-files#recursors) |
| HTTPS_PORT        | `8443` | [port for HTTPS service](https://www.consul.io/docs/agent/config/config-files#https_port) |
| DNS_PORT          | `8600` | [port for DNS service](https://www.consul.io/docs/agent/config/config-files#dns_port) |
| SERVER_NAME       | `consul` | Address of Consul server, it is used for [retry_join](https://www.consul.io/docs/agent/config/cli-flags#_retry_join) |
| CA_CERT           | `/home/app/assets/consul-agent-ca.pem` | CA certificate for Consul datacenter |
| GOSSIP_CONFIG     | `/home/app/assets/agent-gossip-encryption.hcl` | Gossip encryption configuration |

The values are meant to be consistent to the ones used by `generate_consul_client_config.sh`.

The last two values represent files generated by `generate_consul_client_config.sh`.

### Usage

```shell
./generate_consul_server_config.sh
```

The script will generate the following files:

```plaintest
./client_configs/api/
./client_configs/api/consul-agent-ca.pem
./client_configs/api/agent-client-acl-tokens.hcl
./client_configs/api/svc-api.hcl
./client_configs/api/agent-gossip-encryption.hcl
./client_configs/api/agent-client-secure.hcl
./client_configs/db/
./client_configs/db/consul-agent-ca.pem
./client_configs/db/agent-client-acl-tokens.hcl
./client_configs/db/svc-db.hcl
./client_configs/db/agent-gossip-encryption.hcl
./client_configs/db/agent-client-secure.hcl
./client_configs/frontend/
./client_configs/frontend/consul-agent-ca.pem
./client_configs/frontend/agent-client-acl-tokens.hcl
./client_configs/frontend/agent-gossip-encryption.hcl
./client_configs/frontend/svc-frontend.hcl
./client_configs/frontend/agent-client-secure.hcl
./client_configs/nginx/
./client_configs/nginx/consul-agent-ca.pem
./client_configs/nginx/svc-nginx.hcl
./client_configs/nginx/agent-client-acl-tokens.hcl
./client_configs/nginx/agent-gossip-encryption.hcl
./client_configs/nginx/agent-client-secure.hcl
```

## generate_consul_client_config_mesh.sh

Generate service configuration for Consul service mesh that can be used to 
replace the ones generated by the previous script in case you are implementing
Consul service mesh instead of service discovery.

It also generates:

* Global proxy-defaults
* Intention definitions for HashiCups

### Usage

```shell
./generate_consul_client_config_mesh.sh
```

The script will generate the following files:

```plaintext
service_mesh_configs/
|-- global
|   |-- config-global-proxy-default.hcl
|   |-- config-global-proxy-default.json
|   |-- intention-api.hcl
|   |-- intention-api.json
|   |-- intention-db.hcl
|   |-- intention-db.json
|   |-- intention-frontend.hcl
|   `-- intention-frontend.json
|-- hashicups-api
|   `-- svc-hashicups-api.hcl
|-- hashicups-db
|   `-- svc-hashicups-db.hcl
|-- hashicups-frontend
|   `-- svc-hashicups-frontend.hcl
`-- hashicups-nginx
    `-- svc-hashicups-nginx.hcl
```