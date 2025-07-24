

#------------------------------------------------------------------------------#
## Bastion host
#------------------------------------------------------------------------------#

locals {
  bastion_fake_dns = <<EOF
# The following lines are added for hashicups scenario
%{ for index, ip in aws_instance.database.*.private_ip ~}
${ip} hashicups-db-${index} 
%{ endfor ~}
%{ for index, ip in aws_instance.api.*.private_ip ~}
${ip} hashicups-api-${index} 
%{ endfor ~}
%{ for index, ip in aws_instance.frontend.*.private_ip ~}
${ip} hashicups-frontend-${index} 
%{ endfor ~}
%{ for index, ip in aws_instance.nginx.*.private_ip ~}
${ip} hashicups-nginx-${index} hashicups-lb-${index} 
%{ endfor ~}
# There should always be at least one Consul server
${aws_instance.consul_server.0.private_ip} consul server.${var.consul_datacenter}.${var.consul_domain}
%{ for index, ip in aws_instance.consul_server.*.private_ip ~}
${ip} consul-server-${index} 
%{ endfor ~}
%{ for index, ip in aws_instance.gateway-api.*.private_ip ~}
${ip} gateway-api-${index} 
%{ endfor ~}
%{ for index, ip in aws_instance.gateway-mesh.*.private_ip ~}
${ip} gateway-mesh-${index} 
%{ endfor ~}
%{ for index, ip in aws_instance.gateway-terminating.*.private_ip ~}
${ip} gateway-terminating-${index} 
%{ endfor ~}
%{ for index, ip in aws_instance.consul-esm.*.private_ip ~}
${ip} consul-esm-${index} 
%{ endfor ~}
%{ if  length(aws_instance.gateway-api) >= "1" }${aws_instance.gateway-api.0.public_ip}  gateway-api-public gw-api-public%{ else }""%{ endif }
  EOF
}

resource "aws_instance" "bastion" {
  depends_on                  = [module.vpc]
  ami                         = data.aws_ami.debian-12.id
  associate_public_ip_address = true
  instance_type               = "t2.micro"
  key_name                    = aws_key_pair.keypair.id
  vpc_security_group_ids = [
    aws_security_group.ingress-ssh.id,
    aws_security_group.ingress-monitoring-suite.id
  ]
  subnet_id = module.vpc.public_subnets[0]

  tags = {
    Name = "bastion"
  }

  user_data = templatefile("${path.module}/../../../assets/templates/cloud-init/user_data_bastion.tmpl", {
    ssh_public_key  = base64gzip("${tls_private_key.keypair_private_key.public_key_openssh}"),
    ssh_private_key = base64gzip("${tls_private_key.keypair_private_key.private_key_openssh}"),
    hostname        = "bastion",
    username        = "${var.vm_username}",
    consul_version  = "${var.consul_version}",
    HOSTS_EXTRA_CONFIG = base64gzip("${local.bastion_fake_dns}")
  })

  connection {
    type        = "ssh"
    user        = "${var.vm_username}"
    private_key = tls_private_key.keypair_private_key.private_key_pem
    host        = self.public_ip
  }
  # file, local-exec, remote-exec
  # Copy monitoring suite config files
  provisioner "file" {
    source      = "${path.module}/../../../assets"
    destination = "/home/${var.vm_username}/"
  }

  provisioner "file" {
    source      = "${path.module}/../../ops"
    destination = "/home/${var.vm_username}"
  }

  # Waits for cloud-init to complete. Needed for ACL creation.
  provisioner "remote-exec" {
    inline = [
      "echo 'Waiting for user data script to finish'",
      "cloud-init status --wait > /dev/null", 
      "cd /home/${var.vm_username}/ops && bash ./provision.sh operate ${var.scenario}"
    ]
  }

  iam_instance_profile = aws_iam_instance_profile.instance_profile.name

  metadata_options {
    http_endpoint          = "enabled"
    instance_metadata_tags = "enabled"
  }
}

