#------------------------------------------------------------------------------#
## Config Files for scenario
#------------------------------------------------------------------------------#

#------------------------------------------------------------------------------#
## Scenario Environment Variables
#------------------------------------------------------------------------------#

resource "local_file" "scenario_env" {
  content  = templatefile("${path.module}/../../../assets/templates/provision/scenario_env.env.tmpl", {
    consul_datacenter         = var.consul_datacenter,
    consul_domain             = var.consul_domain,
    server_number             = var.server_number,
    retry_join                = local.retry_join,
    cloud_provider            = "aws",
    username                  = "${var.vm_username}",
    log_level                 = var.log_level,
    enable_service_mesh       = var.enable_service_mesh,
    hc_db_number              = var.hc_db_number,
    hc_api_number             = var.hc_api_number,
    hc_fe_number              = var.hc_fe_number,
    hc_lb_number              = var.hc_lb_number,
    api_gw_number             = var.api_gw_number,
    term_gw_number            = var.term_gw_number,
    mesh_gw_number            = var.mesh_gw_number,
    consul_esm_number         = var.consul_esm_number,
    start_monitoring_suite    = var.start_monitoring_suite,
    register_monitoring_suite = var.register_monitoring_suite,
    base_scenario             = var.base_scenario,
    solve_scenario            = var.solve_scenario

  })
  filename = "${path.module}/../../../assets/scenario/scenario_env.env"
}

#------------------------------------------------------------------------------#
## HashiCups Application Starting Scripts
#------------------------------------------------------------------------------#
resource "local_file" "start_hashicups_db" {
  content  = templatefile("${path.module}/../../../assets/templates/provision/start_hashicups_db.sh.tmpl", {
    VERSION                = var.db_version
    CONFIGURE_SERVICE_MESH = var.enable_service_mesh
  })
  filename = "${path.module}/../../../assets/scenario/start_hashicups_db.sh"
}

## [ ] parametrize for hostname
resource "local_file" "start_hashicups_api" {
  content  = templatefile("${path.module}/../../../assets/templates/provision/start_hashicups_api.sh.tmpl", {
    username               = "${var.vm_username}",
    VERSION_PAY            = var.api_payments_version,
    VERSION_PROD           = var.api_product_version,
    VERSION_PUB            = var.api_public_version,
    DB_HOST                = var.enable_service_mesh ? "localhost" : "${element(concat(aws_instance.database.*. private_ip, tolist([""])), 0)}",
    PRODUCT_API_HOST       = "localhost",
    PAYMENT_API_HOST       = "localhost",
    CONFIGURE_SERVICE_MESH = var.enable_service_mesh
  })
  filename = "${path.module}/../../../assets/scenario/start_hashicups_api.sh"
}

## [ ] parametrize for hostname
resource "local_file" "start_hashicups_fe" {
  content  = templatefile("${path.module}/../../../assets/templates/provision/start_hashicups_fe.sh.tmpl", {
    VERSION                = var.fe_version,
    API_HOST               = var.enable_service_mesh ? "localhost" : "${element(concat(aws_instance.api.*. private_ip, tolist([""])), 0)}",
    CONFIGURE_SERVICE_MESH = var.enable_service_mesh
  })
  filename = "${path.module}/../../../assets/scenario/start_hashicups_frontend.sh"
}

## [ ] parametrize for hostname 
resource "local_file" "start_hashicups_nginx" {
  content  = templatefile("${path.module}/../../../assets/templates/provision/start_hashicups_nginx.sh.tmpl", {
    username               = "${var.vm_username}",
    PUBLIC_API_HOST        = var.enable_service_mesh ? "localhost" : "${element(concat(aws_instance.api.*. private_ip, tolist([""])), 0)}",
    FE_HOST                = var.enable_service_mesh ? "localhost" : "${element(concat(aws_instance.frontend.*. private_ip, tolist([""])), 0)}",
    CONFIGURE_SERVICE_MESH = var.enable_service_mesh
  })
  filename = "${path.module}/../../../assets/scenario/start_hashicups_nginx.sh"
}

#------------------------------------------------------------------------------#
## Grafana monitoring suite starting script
#------------------------------------------------------------------------------#

resource "local_file" "start_monitoring_suite" {
  content  = templatefile("${path.module}/../../../assets/templates/provision/start_monitoring_suite.sh.tmpl", {  
    username = "${var.vm_username}"
  })
  filename = "${path.module}/../../../assets/scenario/start_monitoring_suite.sh"
}