#------------------------------------------------------------------------------#
## Consul Server(s)
#------------------------------------------------------------------------------#

resource "aws_instance" "consul_server" {
  depends_on                  = [module.vpc]
  count                       = var.server_number
  ami                         = data.aws_ami.debian-11.id
  associate_public_ip_address = true
  instance_type               = "t2.micro"
  key_name                    = aws_key_pair.keypair.id
  vpc_security_group_ids = [
    aws_security_group.ingress-ssh.id,
    aws_security_group.consul-agents.id,
    aws_security_group.consul-servers.id
  ]
  subnet_id = module.vpc.public_subnets[0]

  tags = {
    Name          = "consul-server-${count.index}",
    ConsulJoinTag = "auto-join-${random_string.suffix.result}"
  }

  user_data = templatefile("${path.module}/../../../assets/templates/cloud-init/user_data_consul_agent.tmpl", {
    ssh_public_key  = base64gzip("${tls_private_key.keypair_private_key.public_key_openssh}"),
    ssh_private_key = base64gzip("${tls_private_key.keypair_private_key.private_key_openssh}"),
    hostname        = "consul-server-${count.index}",
    consul_version  = "${var.consul_version}"
  })

  connection {
    type        = "ssh"
    user        = "admin"
    private_key = tls_private_key.keypair_private_key.private_key_pem
    host        = self.public_ip
  }

  # Waits for cloud-init to complete. Needed for ACL creation.
  provisioner "remote-exec" {
    inline = [
      "echo 'Waiting for user data script to finish'",
      "cloud-init status --wait > /dev/null"
    ]
  }

  iam_instance_profile = aws_iam_instance_profile.instance_profile.name

  metadata_options {
    http_endpoint          = "enabled"
    instance_metadata_tags = "enabled"
  }
}


#------------------------------------------------------------------------------#
## Instance Profile - Needed for cloud join
#------------------------------------------------------------------------------#

resource "aws_iam_instance_profile" "instance_profile" {
  name_prefix = local.name
  role        = aws_iam_role.instance_role.name
}

resource "aws_iam_role" "instance_role" {
  name_prefix        = local.name
  assume_role_policy = data.aws_iam_policy_document.instance_role.json
}

data "aws_iam_policy_document" "instance_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy" "auto_discover_cluster" {
  name   = "${local.name}-auto-discover-cluster"
  role   = aws_iam_role.instance_role.id
  policy = data.aws_iam_policy_document.auto_discover_cluster.json
}

data "aws_iam_policy_document" "auto_discover_cluster" {
  statement {
    effect = "Allow"

    actions = [
      "ec2:DescribeInstances",
      "ec2:DescribeTags",
      "autoscaling:DescribeAutoScalingGroups",
    ]

    resources = ["*"]
  }
}