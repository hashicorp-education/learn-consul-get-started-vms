

#------------------------------------------------------------------------------#
## HashiCups
#------------------------------------------------------------------------------#

#------------#
#  API GW    #
#------------#

resource "aws_instance" "gateway-api" {
  depends_on    = [module.vpc]
  ami           = data.aws_ami.debian-11.id
  instance_type = "t2.micro"
  key_name      = aws_key_pair.keypair.id
  vpc_security_group_ids = [
    aws_security_group.ingress-ssh.id,
    aws_security_group.ingress-gw-api.id,
    aws_security_group.consul-agents.id,
    aws_security_group.ingress-envoy.id
  ]
  subnet_id = module.vpc.public_subnets[0]

  tags = {
    Name = "gateway-api"
  }

  user_data = templatefile("${path.module}/../../../assets/templates/cloud-init/user_data_consul_agent.tmpl", {
    ssh_public_key  = base64gzip("${tls_private_key.keypair_private_key.public_key_openssh}"),
    ssh_private_key = base64gzip("${tls_private_key.keypair_private_key.private_key_openssh}"),
    hostname        = "gateway-api",
    consul_version  = "${var.consul_version}"
  })

  connection {
    type        = "ssh"
    user        = "admin"
    private_key = tls_private_key.keypair_private_key.private_key_pem
    host        = self.public_ip
  }
  # file, local-exec, remote-exec
  ## Install Envoy
  provisioner "file" {
    content     = templatefile("${path.module}/../../../assets/templates/provision/install_envoy.sh.tmpl", {})
    destination = "/home/admin/install_envoy.sh" # remote machine
  }

  iam_instance_profile = aws_iam_instance_profile.instance_profile.name

  metadata_options {
    http_endpoint          = "enabled"
    instance_metadata_tags = "enabled"
  }
}
