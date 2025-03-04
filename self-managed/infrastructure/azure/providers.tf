terraform {
  required_version = ">= 0.12"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">=3.0.0"
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


provider "azurerm" {
  features {}

  subscription_id = var.subscription_id
  client_id = var.client_id
  client_secret = var.client_secret
  tenant_id = var.tenant_id
}