resource "azurerm_resource_group" "hashistack" {
  name     = "hashistack-${local.name_suffix}"
  location = var.location
}

resource "azurerm_virtual_network" "hashistack-vn" {
  name                = "hashistack-vn"
  address_space       = ["10.0.0.0/16"]
  location            = "${var.location}"
  resource_group_name = "${azurerm_resource_group.hashistack.name}"
}

resource "azurerm_subnet" "hashistack-sn" {
  name                 = "hashistack-sn"
  resource_group_name  = "${azurerm_resource_group.hashistack.name}"
  virtual_network_name = "${azurerm_virtual_network.hashistack-vn.name}"
  address_prefixes       = ["10.0.2.0/24"]
}

resource "azurerm_network_security_group" "bastion-host" {
    name               = "bastion-host-sg"
    location            = "${var.location}"
    resource_group_name = "${azurerm_resource_group.hashistack.name}"
    
    security_rule {
        name                       = "SSH"
        priority                   = 100
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = 22
        source_address_prefix      = "*"
        destination_address_prefix = "*"
    }

    # The protocol attribute doesn't accept a list. You would either need to create two security rules, or use * for the protocol. 
    # https://stackoverflow.com/questions/74494380/how-do-i-create-a-security-rules-with-multiple-protocols-using-terraform-in-azur

    security_rule {
        name                       = "Monitoring-suite"
        priority                   = 101
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_ranges    = [ 3000, 9009, 3100]
        source_address_prefix      = "*"
        destination_address_prefix = "*"
    }
}

resource "azurerm_network_security_group" "consul-server" {
    name               = "consul-server-sg"
    location            = "${var.location}"
    resource_group_name = "${azurerm_resource_group.hashistack.name}"
    
    security_rule {
        name                       = "SSH"
        priority                   = 100
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = 22
        source_address_prefix      = "*"
        destination_address_prefix = "*"
    }

    # The protocol attribute doesn't accept a list. You would either need to create two security rules, or use * for the protocol. 
    # https://stackoverflow.com/questions/74494380/how-do-i-create-a-security-rules-with-multiple-protocols-using-terraform-in-azur

    security_rule {
        name                       = "Consul-server"
        priority                   = 101
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "*"
        source_port_range          = "*"
        destination_port_ranges    = [ 8301, 8300, "8500-8503", 8443, 8302, 8600 ]
        source_address_prefix      = "*"
        destination_address_prefix = "*"
    }
}

resource "azurerm_network_security_group" "consul-client" {
    name               = "consul-client-sg"
    location            = "${var.location}"
    resource_group_name = "${azurerm_resource_group.hashistack.name}"
    
    security_rule {
        name                       = "SSH"
        priority                   = 100
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = 22
        source_address_prefix      = "*"
        destination_address_prefix = "*"
    }

    # The protocol attribute doesn't accept a list. You would either need to create two security rules, or use * for the protocol. 
    # https://stackoverflow.com/questions/74494380/how-do-i-create-a-security-rules-with-multiple-protocols-using-terraform-in-azur

    security_rule {
        name                       = "Consul-client"
        priority                   = 101
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "*"
        source_port_range          = "*"
        destination_port_ranges    = [ 8301, 8443]
        source_address_prefix      = "*"
        destination_address_prefix = "*"
    }

    security_rule {
        name                       = "Service-Mesh"
        priority                   = 102
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "*"
        source_port_range          = "*"
        destination_port_ranges    = [ "21000-21255" ]
        source_address_prefix      = "*"
        destination_address_prefix = "*"
    }
}

resource "azurerm_network_security_group" "consul-service" {
    name               = "consul-service-sg"
    location            = "${var.location}"
    resource_group_name = "${azurerm_resource_group.hashistack.name}"
    
    security_rule {
        name                       = "SSH"
        priority                   = 100
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = 22
        source_address_prefix      = "*"
        destination_address_prefix = "*"
    }

    # The protocol attribute doesn't accept a list. You would either need to create two security rules, or use * for the protocol. 
    # https://stackoverflow.com/questions/74494380/how-do-i-create-a-security-rules-with-multiple-protocols-using-terraform-in-azur

    security_rule {
        name                       = "Consul-client"
        priority                   = 101
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "*"
        source_port_range          = "*"
        destination_port_ranges    = [ 8301 ]
        source_address_prefix      = "*"
        destination_address_prefix = "*"
    }

    security_rule {
        name                       = "Service-Mesh"
        priority                   = 102
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "*"
        source_port_range          = "*"
        destination_port_ranges    = [ "21000-21255" ]
        source_address_prefix      = "*"
        destination_address_prefix = "*"
    }

    security_rule {
        name                       = "HashiCups"
        priority                   = 103
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "*"
        source_port_range          = "*"
        destination_port_ranges    = [ 80, 3000, 8081, 5432 ]
        source_address_prefix      = "*"
        destination_address_prefix = "*"
    }
}
