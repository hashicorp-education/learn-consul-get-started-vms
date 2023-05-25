

#------------------------------------------------------------------------------#
## Bastion host
#------------------------------------------------------------------------------#

locals {
  bastion_fake_dns = <<EOF
# The following lines are added for hashicups scenario
${aws_instance.nginx.private_ip} hashicups-nginx nginx
${aws_instance.frontend.private_ip} hashicups-frontend frontend
${aws_instance.api.private_ip} hashicups-api api
${aws_instance.database.private_ip} hashicups-db database db
${aws_instance.consul_server.0.private_ip} consul-server-0 consul server.${var.consul_datacenter}.${var.consul_domain}
${aws_instance.gateway-api.private_ip} gateway-api gw-api
  EOF
}

resource "aws_instance" "bastion" {
  depends_on                  = [module.vpc]
  ami                         = data.aws_ami.debian-11.id
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

  user_data = templatefile("${path.module}/../../assets/templates/cloud-init/user_data_bastion.tmpl", {
    ssh_public_key  = base64gzip("${tls_private_key.keypair_private_key.public_key_openssh}"),
    ssh_private_key = base64gzip("${tls_private_key.keypair_private_key.private_key_openssh}"),
    hostname        = "bastion",
    consul_version  = "${var.consul_version}",
    # HOSTS_EXTRA_CONFIG = base64gzip("${data.template_file.dns_extra_conf.rendered}")
    HOSTS_EXTRA_CONFIG = base64gzip("${local.bastion_fake_dns}")
  })

  connection {
    type        = "ssh"
    user        = "admin"
    private_key = tls_private_key.keypair_private_key.private_key_pem
    host        = self.public_ip
  }
  # file, local-exec, remote-exec
  # Copy monitoring suite config files
  provisioner "file" {
    source      = "${path.module}/../../assets"
    destination = "/home/admin/"
  }

  provisioner "file" {
    source      = "${path.module}/../../ops"
    destination = "/home/admin"
  }

  # Waits for cloud-init to complete. Needed for ACL creation.
  provisioner "remote-exec" {
    inline = [
      "echo 'Waiting for user data script to finish'",
      "cloud-init status --wait > /dev/null", 
      "cd /home/admin/ops && bash ./provision.sh operate ${var.scenario}"
    ]
  }

  iam_instance_profile = aws_iam_instance_profile.instance_profile.name

  metadata_options {
    http_endpoint          = "enabled"
    instance_metadata_tags = "enabled"
  }
}

