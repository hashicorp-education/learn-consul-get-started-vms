# # Declare TF variables
# resource "random_string" "suffix" {
#   length  = 4
#   special = false
#   upper   = false
# }

# locals {
#   name = "${var.prefix}-${random_string.suffix.result}"
# }

# locals {
#   retry_join = "provider=aws tag_key=ConsulJoinTag tag_value=auto-join-${random_string.suffix.result}"
# }

# ## Flow Control
# variable "prefix" {
#   description = "The prefix used for all resources in this plan"
#   default     = "learn-consul-vms"
# }

# ## AWS networking
# variable "vpc_region" {
#   default = "us-west-2"
# }

#------------------------------------------------------------------------------#
## Consul tuning
#------------------------------------------------------------------------------#
variable "consul_datacenter" {
  description = "Consul datacenter"
  default     = "dc1"
}

variable "consul_domain" {
  description = "Consul domain"
  default     = "consul"
}

# Consul version to install on the clients. Supports:
# - exact version         "x.y.z" (e.g. "1.15.0")
# - latest minor version  "x.y"   (e.g. "1.14" for latest minor vesrion for 1.14)
# - latest version        "latest"
## todo currently ignored
variable "consul_version" {
  description = "Consul version to install on VMs"
  default     = "1.16"
}

# variable "envoy_version" {
#   description = "Envoy version to install on VMs"
#   default     = "1.26.2"
# }

variable "server_number" {
  description = "Number of Consul servers to deploy. Should be 1, 3, 5, 7."
  default     = "1"
}

variable "retry_join" {
  description = "Used by Consul to automatically join other nodes."
  type        = string
  default     = "consul-server-0"
}


# #------------------------------------------------------------------------------#
# ## HashiCups tuning
# #------------------------------------------------------------------------------#

# variable "db_version" {
#   description = "Version for the HashiCups DB image to be deployed"
#   default     = "v0.0.22"
# }

# variable "api_payments_version" {
#   description = "Version for the HashiCups Payments API image to be deployed"
#   default     = "latest"
# }

# variable "api_product_version" {
#   description = "Version for the HashiCups Product API image to be deployed"
#   default     = "v0.0.22"
# }

# variable "api_public_version" {
#   description = "Version for the HashiCups Public API image to be deployed"
#   default     = "v0.0.7"
# }

# variable "fe_version" {
#   description = "Version for the HashiCups Frontend image to be deployed"
#   default     = "v1.0.9"
# }

#------------------------------------------------------------------------------#
## Scenario tuning
#------------------------------------------------------------------------------#

variable "scenario" {
  description = "Prerequisites scenario to run at the end of infrastructure provision"
  default     = "00_base"
}