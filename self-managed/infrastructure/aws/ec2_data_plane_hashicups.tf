

#------------------------------------------------------------------------------#
## HashiCups
#------------------------------------------------------------------------------#

#------------#
#  DATABASE  #
#------------#

resource "aws_instance" "database" {
  depends_on    = [module.vpc]
  count         = var.hc_db_number
  ami           = data.aws_ami.debian-12.id
  instance_type = "t2.micro"
  key_name      = aws_key_pair.keypair.id
  vpc_security_group_ids = [
    aws_security_group.ingress-ssh.id,
    aws_security_group.ingress-db.id,
    aws_security_group.consul-agents.id,
    aws_security_group.ingress-envoy.id
  ]
  subnet_id = module.vpc.public_subnets[0]

  tags = {
    Name = "hashicups-db-${count.index}"
    Application = "hashicups"
  }

  user_data = templatefile("${path.module}/../../../assets/templates/cloud-init/user_data_consul_agent.tmpl", {
    ssh_public_key  = base64gzip("${tls_private_key.keypair_private_key.public_key_openssh}"),
    ssh_private_key = base64gzip("${tls_private_key.keypair_private_key.private_key_openssh}"),
    hostname        = "hashicups-db-${count.index}",
    username        = "${var.vm_username}",
    consul_version  = "${var.consul_version}"
  })

  connection {
    type        = "ssh"
    user        = "${var.vm_username}"
    private_key = tls_private_key.keypair_private_key.private_key_pem
    host        = self.public_ip
  }
  # # file, local-exec, remote-exec
  # ## Install Envoy
  # provisioner "file" {
  #   content     = templatefile("${path.module}/../../../assets/templates/provision/install_envoy.sh.tmpl", {})
  #   destination = "/home/${var.vm_username}/install_envoy.sh" # remote machine
  # }

  iam_instance_profile = aws_iam_instance_profile.instance_profile.name

  metadata_options {
    http_endpoint          = "enabled"
    instance_metadata_tags = "enabled"
  }
}

#------------#
#    API     #
#------------#

resource "aws_instance" "api" {
  depends_on    = [module.vpc]
  count         = var.hc_api_number
  ami           = data.aws_ami.debian-12.id
  instance_type = "t2.micro"
  key_name      = aws_key_pair.keypair.id
  vpc_security_group_ids = [
    aws_security_group.ingress-ssh.id,
    aws_security_group.ingress-api.id,
    aws_security_group.consul-agents.id,
    aws_security_group.ingress-envoy.id
  ]
  subnet_id = module.vpc.public_subnets[0]

  tags = {
    Name = "hashicups-api-${count.index}"
    Application = "hashicups"
  }

  user_data = templatefile("${path.module}/../../../assets/templates/cloud-init/user_data_consul_agent.tmpl", {
    ssh_public_key  = base64gzip("${tls_private_key.keypair_private_key.public_key_openssh}"),
    ssh_private_key = base64gzip("${tls_private_key.keypair_private_key.private_key_openssh}"),
    hostname        = "hashicups-api-${count.index}",
    username        = "${var.vm_username}",
    consul_version  = "${var.consul_version}"
  })

  connection {
    type        = "ssh"
    user        = "${var.vm_username}"
    private_key = tls_private_key.keypair_private_key.private_key_pem
    host        = self.public_ip
  }
  # # file, local-exec, remote-exec
  # ## Install Envoy
  # provisioner "file" {
  #   content     = templatefile("${path.module}/../../../assets/templates/provision/install_envoy.sh.tmpl", {})
  #   destination = "/home/${var.vm_username}/install_envoy.sh" # remote machine
  # }

  iam_instance_profile = aws_iam_instance_profile.instance_profile.name

  metadata_options {
    http_endpoint          = "enabled"
    instance_metadata_tags = "enabled"
  }
}

#------------#
#  FRONTEND  #
#------------#

resource "aws_instance" "frontend" {
  depends_on    = [module.vpc]
  count         = var.hc_fe_number
  ami           = data.aws_ami.debian-12.id
  instance_type = "t2.micro"
  key_name      = aws_key_pair.keypair.id
  vpc_security_group_ids = [
    aws_security_group.ingress-ssh.id,
    aws_security_group.ingress-fe.id,
    aws_security_group.consul-agents.id,
    aws_security_group.ingress-envoy.id
  ]
  subnet_id = module.vpc.public_subnets[0]

  tags = {
    Name = "hashicups-frontend-${count.index}"
    Application = "hashicups"
  }

  user_data = templatefile("${path.module}/../../../assets/templates/cloud-init/user_data_consul_agent.tmpl", {
    ssh_public_key  = base64gzip("${tls_private_key.keypair_private_key.public_key_openssh}"),
    ssh_private_key = base64gzip("${tls_private_key.keypair_private_key.private_key_openssh}"),
    hostname        = "hashicups-frontend-${count.index}",
    username        = "${var.vm_username}",
    consul_version  = "${var.consul_version}"
  })

  connection {
    type        = "ssh"
    user        = "${var.vm_username}"
    private_key = tls_private_key.keypair_private_key.private_key_pem
    host        = self.public_ip
  }
  # # file, local-exec, remote-exec
  # ## Install Envoy
  # provisioner "file" {
  #   content     = templatefile("${path.module}/../../../assets/templates/provision/install_envoy.sh.tmpl", {})
  #   destination = "/home/${var.vm_username}/install_envoy.sh" # remote machine
  # }

  iam_instance_profile = aws_iam_instance_profile.instance_profile.name

  metadata_options {
    http_endpoint          = "enabled"
    instance_metadata_tags = "enabled"
  }
}

#------------#
#   NGINX    #
#------------#

resource "aws_instance" "nginx" {
  depends_on                  = [module.vpc]
  count                       = var.hc_lb_number
  ami                         = data.aws_ami.debian-12.id
  associate_public_ip_address = true
  instance_type               = "t2.micro"
  key_name                    = aws_key_pair.keypair.id
  vpc_security_group_ids = [
    aws_security_group.ingress-ssh.id,
    aws_security_group.ingress-web.id,
    aws_security_group.consul-agents.id,
    aws_security_group.ingress-envoy.id
  ]
  subnet_id = module.vpc.public_subnets[0]

  tags = {
    Name = "hashicups-nginx-${count.index}"
    Application = "hashicups"
  }

  user_data = templatefile("${path.module}/../../../assets/templates/cloud-init/user_data_consul_agent.tmpl", {
    ssh_public_key  = base64gzip("${tls_private_key.keypair_private_key.public_key_openssh}"),
    ssh_private_key = base64gzip("${tls_private_key.keypair_private_key.private_key_openssh}"),
    hostname        = "hashicups-nginx-${count.index}",
    username        = "${var.vm_username}",
    consul_version  = "${var.consul_version}"
  })

  connection {
    type        = "ssh"
    user        = "${var.vm_username}"
    private_key = tls_private_key.keypair_private_key.private_key_pem
    host        = self.public_ip
  }
  # # file, local-exec, remote-exec
  # ## Install Envoy
  # provisioner "file" {
  #   content     = templatefile("${path.module}/../../../assets/templates/provision/install_envoy.sh.tmpl", {})
  #   destination = "/home/${var.vm_username}/install_envoy.sh" # remote machine
  # }

  iam_instance_profile = aws_iam_instance_profile.instance_profile.name

  metadata_options {
    http_endpoint          = "enabled"
    instance_metadata_tags = "enabled"
  }
}