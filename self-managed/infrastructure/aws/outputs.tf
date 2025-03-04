// A variable for extracting the external ip of the instance
output "ip_bastion" {
  value = aws_instance.bastion.public_ip
}

output "connection_string" {
  value = "ssh -i certs/id_rsa.pem ${var.vm_username}@`terraform output -raw ip_bastion`"
}

output "ui_hashicups" {
  value = "http://${aws_instance.nginx.0.public_ip}"
  # value = "${element(concat(aws_instance.nginx.*. public_ip, tolist([""])), 0)}"
}

output "ui_hashicups_API_GW" {
  value = var.enable_service_mesh ? "https://${aws_instance.gateway-api.0.public_ip}:8443" : null
}

output "ui_consul" {
  value = "https://${aws_instance.consul_server.0.public_ip}:8443"
}

output "ui_grafana" {
  value = "http://${aws_instance.bastion.public_ip}:3000/d/hashicups/hashicups"
}

# output "remote_ops" {
#   value = "export BASTION_HOST=${aws_instance.bastion.public_ip}"
# }

output "retry_join" {
  value = local.retry_join
  sensitive = true
}