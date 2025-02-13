#------------------------------------------------------------------------------#
## Admin Username
#------------------------------------------------------------------------------#
## Azure does not permit to have `admin` username but AWS has `admin` username as default.
## To resolve this in the generic scenarios, we define a variable that contains the username 
## so that all the scripts can be generated parametrically from it.
## !! IMPORTANT !! Changing this variable ONLY creates the user in the VM in Azure.
## For Docker and AWS use the default value `admin`.

variable "vm_username" {
  default = "admin"
}

#------------------------------------------------------------------------------#
## Instruqt Participant ID
#------------------------------------------------------------------------------#
# Only populated in instruqt scenarios or if TF_VAR_instruqt_participant_id is set.
variable instruqt_participant_id {
  default = ""
}

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
## todo currently ignored - Images are build with a pre-loaded version of Consul installed
variable "consul_version" {
  description = "Consul version to install on VMs"
  default     = "1.16"
}

variable "server_number" {
  description = "Number of Consul servers to deploy. Should be 1, 3, 5, 7."
  default     = "1"
}

variable "retry_join" {
  description = "Used by Consul to automatically join other nodes."
  type        = string
  default     = "consul-server-0"
}

#------------------------------------------------------------------------------#
## Consul Flow
#------------------------------------------------------------------------------#

variable "enable_service_mesh" {
  description = "If set to true configures services for service mesh, otherwise for service discovery"
  default = true
}

#------------------------------------------------------------------------------#
## Consul datacenter Tuning
#------------------------------------------------------------------------------#

variable "api_gw_number" {
  description = "Number of instances for Consul API Gateways"
  default     = "1"
}

variable "term_gw_number" {
  description = "Number of instances for Consul Terminating Gateways"
  default     = "0"
}

variable "mesh_gw_number" {
  description = "Number of instances for Consul Mesh Gateways"
  default     = "0"
}

variable "consul_esm_number" {
  description = "Number of instances for Consul ESM nodes"
  default     = "0"
}

#------------------------------------------------------------------------------#
## HashiCups tuning
#------------------------------------------------------------------------------#

variable "hc_db_number" {
  description = "Number of instances for HashiCups DB service"
  default     = "1"
}

variable "hc_api_number" {
  description = "Number of instances for HashiCups API service"
  default     = "1"
}

variable "hc_fe_number" {
  description = "Number of instances for HashiCups Frontend service"
  default     = "1"
}

variable "hc_lb_number" {
  description = "Number of instances for HashiCups NGINX service"
  default     = "1"
}

#------------------------------------------------------------------------------#
## Monitoring Tuning
#------------------------------------------------------------------------------#

variable "start_monitoring_suite" {
  description = "Number of instances for Consul ESM nodes"
  default     = "false"
}

variable "register_monitoring_suite" {
  description = "Register monitoring suite nodes as external services in Consul"
  default     = "false"
}

#------------------------------------------------------------------------------#
## Scenario tuning
#------------------------------------------------------------------------------#

variable "base_scenario" {
  description = "Base scenario that represents the starting point of the infrastructure"
  default     = "base_consul_dc"
}

variable "scenario" {
  description = "Prerequisites scenario to run at the end of infrastructure provision"
  default     = "00_test_base"
}

variable "solve_scenario" {
  description = "If a solution script is provided, tests the solution against the scenario."
  default     = "false"
}

variable "log_level" {
  description = "Log level for the scenario provisioning script. Allowed values are 0,1,2,3,4"
  default     = "2"
}