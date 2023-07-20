# Defines Consul version to install on agents
consul_version = "latest"

# Name of the Consul datacenter to deploy
consul_datacenter = "dc1"

# Name of the Consul domain
consul_domain = "consul"

# Number of Consul servers to deploy for Consul control plane
server_number = 3

## Scenario configuration
scenario = "01_consul_control_plane"

## Log level for the scenario operate scripts.
log_level = 2