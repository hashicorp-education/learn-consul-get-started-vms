data "aws_availability_zones" "available" {
  state = "available"

  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "3.19.0"

  name = local.name

  cidr = "10.0.0.0/16"
  azs  = slice(data.aws_availability_zones.available.names, 0, 3)

  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]

  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true

}

resource "aws_security_group" "ingress-ssh" {
  name   = "allow-all-sg"
  vpc_id = module.vpc.vpc_id
  ingress {
    cidr_blocks = [
      "0.0.0.0/0"
    ]
    from_port = 22
    to_port   = 22
    protocol  = "tcp"
  }
  // Terraform removes the default rule
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "ingress-web" {
  name   = "allow-web-sg"
  vpc_id = module.vpc.vpc_id
  ingress {
    cidr_blocks = [
      "0.0.0.0/0"
    ]
    from_port = 80
    to_port   = 80
    protocol  = "tcp"
  }
  // Terraform removes the default rule
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "ingress-db" {
  name   = "allow-db-sg"
  vpc_id = module.vpc.vpc_id
  ingress {
    cidr_blocks = [
      "0.0.0.0/0"
    ]
    from_port = 5432
    to_port   = 5432
    protocol  = "tcp"
  }
  // Terraform removes the default rule
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "ingress-api" {
  name   = "allow-api-sg"
  vpc_id = module.vpc.vpc_id
  ingress {
    cidr_blocks = [
      "0.0.0.0/0"
    ]
    from_port = 8081
    to_port   = 8081
    protocol  = "tcp"
  }
  // Terraform removes the default rule
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "ingress-fe" {
  name   = "allow-fe-sg"
  vpc_id = module.vpc.vpc_id
  ingress {
    cidr_blocks = [
      "0.0.0.0/0"
    ]
    from_port = 3000
    to_port   = 3000
    protocol  = "tcp"
  }
  // Terraform removes the default rule
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "consul-agents" {
  name   = "allow-consul-agents-sg"
  vpc_id = module.vpc.vpc_id

  # allow_serf_lan_tcp_inbound
  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 8301
    to_port     = 8301
    protocol    = "tcp"
  }

  # allow_serf_lan_udp_inbound
  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 8301
    to_port     = 8301
    protocol    = "udp"
  }

  // Terraform removes the default rule
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "consul-servers" {
  name   = "allow-consul-servers-sg"
  vpc_id = module.vpc.vpc_id

  # allow_server_rcp_tcp_inbound
  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 8300
    to_port     = 8300
    protocol    = "tcp"
  }

  # allow_server_http_and_grpc_inbound - HTTP:8500 | HTTPS:8501 | GRPC:8502 | GRPCS:8503
  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 8500
    to_port     = 8503
    protocol    = "tcp"
  }

  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 8443
    to_port     = 8443
    protocol    = "tcp"
  }

  # allow_serf_wan_tcp_inbound
  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 8302
    to_port     = 8302
    protocol    = "tcp"
  }

  # allow_serf_wan_udp_inbound
  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 8302
    to_port     = 8302
    protocol    = "udp"
  }

  # allow_dns_tcp_inbound
  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 8600
    to_port     = 8600
    protocol    = "tcp"
  }

  # allow_dns_udp_inbound
  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 8600
    to_port     = 8600
    protocol    = "udp"
  }

  // Terraform removes the default rule
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "ingress-monitoring-suite" {
  name   = "allow-monitoring-suite-sg"
  vpc_id = module.vpc.vpc_id

  # Allow Grafana Access
  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
  }

  # Allow Mimir Access
  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 9009
    to_port     = 9009
    protocol    = "tcp"
  }

  # Allow Loki Access
  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 3100
    to_port     = 3100
    protocol    = "tcp"
  }

  // Terraform removes the default rule
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

}

resource "aws_security_group" "ingress-envoy" {
  name   = "allow-envoy-sg"
  vpc_id = module.vpc.vpc_id

  # Allow Grafana Access
  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 21000
    to_port     = 21255
    protocol    = "tcp"
  }
  
  // Terraform removes the default rule
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "ingress-gw-api" {
  name   = "allow-api-gw-sg"
  vpc_id = module.vpc.vpc_id

  # Allow Grafana Access
  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 8443
    to_port     = 8443
    protocol    = "tcp"
  }
  
  // Terraform removes the default rule
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}