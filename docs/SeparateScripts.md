[Home](../README.md)

# Separate Scripts

Consul configuration workflow requires several steps to proper implement all the security layers that Consul offers.

While using a managed solution, such as HCP Consul, is the fastest and recommended way to reduce Consul configuration overhead, it is possible to automate all the required operations.

The scripts in this collection aim to provide runbooks for the steps required to generate a working Consul datacenter environment configuration.

## Prerequisites

> **Warning:** scripts are written in Bash and tested mostly on Linux Debian/Ubuntu. The scripts require `GNU/coreutils` as well as `GNU/grep` to work as expected. Use at your own risk!!!

While the single script requirements might differ slightly from another script ones, this is a general list of prerequisites for the scripts.

* `consul` binary installed to generate secrets and interact with your Consul datacenter.
* `jq` binary installed to manipulate configuration files and command output.

### Script tuning

You can tune the script behavior via environment variables.

Each script has a set of variables used to tailor the generated configuration.

It is mandatory to set some of the variables. The script will exit with an error if one of those variables are not set.

To set variables for a script declare the needed variables in the command line before running the script.

```
export REQUIRED_VARIABLE="required_value"
...
./configuration_script.sh
```

## Configure Control Plane

These scripts are used to generate configuration for Consul server agents.

They are used in self-managed scenarios that require manual configuration for Consul servers. 

### generate_consul_server_config.sh

|     | Variable | R/D | Description
| --- | -------- | --- | -----------
| **Mandatory**
|     | CONSUL_RETRY_JOIN | * | `retry_join` value for Consul configuration.
|     | OUTPUT_FOLDER | * | Path where to save generated Consul configuration files and secrets.
| **Process**
| | CONSUL_CONFIG_DIR | `/etc/consul.d/` | 
| | CONSUL_DATA_DIR | `/opt/consul/` |
| | CONSUL_LOG_LEVEL |`DEBUG` | 
| **Datacenter**
| | CONSUL_DATACENTER |`dc1` |
| | CONSUL_DOMAIN |`consul` |
| | CONSUL_SERVER_NUMBER |`1` |
| **Networking**
| | CONSUL_DNS_RECURSOR | `1.1.1.1` |
| | CONSUL_DNS_PORT | `8600` |
| | CONSUL_HTTPS_PORT | `8443` |
| **Secrets**
| | CONSUL_GOSSIP_KEY | `<empty>` | When set uses a predefined gossip encryption key. 

### generate_consul_server_tokens.sh

|     | Variable | R/D | Description
| --- | -------- | --- | -----------
| **Mandatory**
|     | OUTPUT_FOLDER | * | Path where to save generated Consul configuration files and secrets.
| **Secrets**
| | CONSUL_HTTP_TOKEN | * | A valid Consul management token.
| **Datacenter**
| | CONSUL_DATACENTER |`dc1` |
| | CONSUL_DOMAIN |`consul` |
| | CONSUL_SERVER_NUMBER |`1` |

## Configure Data Plane

These scripts are used to generate configuration for Consul clients and services.

### generate_consul_client_config.sh

|     | Variable | R/D | Description
| --- | -------- | --- | -----------
| **Mandatory**
|     | OUTPUT_FOLDER | * | Path where to save generated Consul configuration files and secrets.
|     | NODE_NAME | * | The script generates the configuration for the node passed as argument.
|     | CONSUL_RETRY_JOIN | * | `retry_join` value for Consul configuration.
| **Process**
| | CONSUL_CONFIG_DIR | `/etc/consul.d/` | 
| | CONSUL_DATA_DIR | `/opt/consul/` |
| | CONSUL_LOG_LEVEL |`DEBUG` | 
| **Datacenter**
| | CONSUL_DATACENTER |`dc1` |
| | CONSUL_DOMAIN |`consul` |

### generate_consul_service_config.sh

> **Warning:** This script is intended to generate service configuration files for the [HashiCups](HashiCups.md) application. For this reason it contains some hardcoded values that require tuning to be applied to a different scenario.

|     | Variable | R/D | Description
| --- | -------- | --- | -----------
| **Mandatory**
|     | OUTPUT_FOLDER | * | Path where to save generated Consul configuration files and secrets.
|     | NODE_NAME | * | The script generates the configuration for the node passed as argument.

