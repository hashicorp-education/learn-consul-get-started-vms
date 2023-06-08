terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.55.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 2"
    }
    local = {
      source  = "hashicorp/local"
      version = ">= 2.2.3"
    }
    http = {
      source  = "hashicorp/http"
      version = ">= 3.2.1"
    }
    cloudinit = {
      source  = "hashicorp/cloudinit"
      version = ">= 2.2.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = ">= 4.0.4"
    }
    consul = {
      source  = "hashicorp/consul"
      version = ">=2.17.0"
    }
    time = {
      source  = "hashicorp/time"
      version = ">=0.9.1"
    }
  }
}

provider "aws" {
  region = var.vpc_region
}