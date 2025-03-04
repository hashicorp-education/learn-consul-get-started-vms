// A variable for extracting the external ip of the instance
output "ip_bastion" {
  value = azurerm_linux_virtual_machine.bastion.public_ip_address
}

output "connection_string" {
  value = "ssh -i certs/id_rsa.pem ${var.vm_username}@`terraform output -raw ip_bastion`"
}

output "ui_hashicups" {
  value = "http://${azurerm_linux_virtual_machine.hashicups-nginx[0].public_ip_address}"
}

output "ui_hashicups_API_GW" {
  value = var.enable_service_mesh ? "https://${azurerm_linux_virtual_machine.gateway-api[0].public_ip_address}:8443" : null
}

output "ui_consul" {
  value = "https://${azurerm_linux_virtual_machine.consul-server[0].public_ip_address}:8443"
}

output "ui_grafana" {
  value = var.start_monitoring_suite ? "http://${azurerm_linux_virtual_machine.bastion.public_ip_address}:3000/d/hashicups/hashicups" : null
}

# output "remote_ops" {
#   value = "export BASTION_HOST=${azurerm_linux_virtual_machine.bastion.public_ip_address}"
# }

output "retry_join" {
  value = local.retry_join
  sensitive = true
}