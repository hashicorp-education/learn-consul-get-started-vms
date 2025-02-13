#------------------------------------------------------------------------------#
## Config Files for scenario
#------------------------------------------------------------------------------#

#------------------------------------------------------------------------------#
## Scenario Environment Variables
#------------------------------------------------------------------------------#

resource "local_file" "scenario_env" {
  content = templatefile("${path.module}/../../../assets/templates/provision/scenario_env.env.tmpl", {
    consul_datacenter         = var.consul_datacenter,
    consul_domain             = var.consul_domain,
    server_number             = var.server_number,
    retry_join                = var.retry_join,
    cloud_provider            = "docker",
    instruqt_participant_id   = var.instruqt_participant_id,
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
