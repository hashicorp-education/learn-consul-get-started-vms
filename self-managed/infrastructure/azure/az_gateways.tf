

#------------------------------------------------------------------------------#
# Gateways and Consul ESM
#------------------------------------------------------------------------------#

#------------#
#  API GW    #
#------------#

resource "azurerm_public_ip" "gateway-api-pip" {
  count               = "${var.api_gw_number}"
  name                = "gateway-api-${count.index}-ip"
  location            = "${var.location}"
  resource_group_name = "${azurerm_resource_group.hashistack.name}"
  # allocation_method   = "Dynamic"
  allocation_method   = "Static"
}

resource "azurerm_network_interface" "gateway-api-nic" {
  count               = "${var.api_gw_number}"
  name                = "gateway-api-${count.index}-nic"
  location            = "${var.location}"
  resource_group_name = "${azurerm_resource_group.hashistack.name}"

  ip_configuration {
    name                          = "gateway-api-${count.index}-ipconfig"
    subnet_id                     = "${azurerm_subnet.hashistack-sn.id}"
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = "${element(azurerm_public_ip.gateway-api-pip.*.id, count.index)}"
  }

  tags                            = {"ConsulJoinTag" = "auto-join-${local.name_suffix}"}
}

resource "azurerm_network_interface_security_group_association" "gateway-api-nic-sg-ass" {
  count                     = "${var.api_gw_number}"
  network_interface_id      = "${element(azurerm_network_interface.gateway-api-nic.*.id, count.index)}"
  network_security_group_id = "${azurerm_network_security_group.consul-client.id}"
}

resource "azurerm_linux_virtual_machine" "gateway-api" {
  count                 = "${var.api_gw_number}"
  name                  = "gateway-api-${count.index}"
  location              = "${var.location}"
  resource_group_name   = "${azurerm_resource_group.hashistack.name}"
  network_interface_ids = [ "${element(azurerm_network_interface.gateway-api-nic.*.id, count.index)}" ]
  size                  = "Standard_B2s"

  # source_image_id       = "${data.azurerm_platform_image.debian.id}"

  source_image_reference {
    publisher = "${data.azurerm_platform_image.debian.publisher}"
    offer     = "${data.azurerm_platform_image.debian.offer}"
    sku       = "${data.azurerm_platform_image.debian.sku}"
    version   = "${data.azurerm_platform_image.debian.version}"
  }

  computer_name  = "gateway-api-${count.index}"
  admin_username = "${var.vm_username}"  

  user_data = "${base64encode(templatefile("${path.module}/../../../assets/templates/cloud-init/user_data_consul_agent.tmpl", {
    ssh_public_key  = base64gzip("${tls_private_key.keypair_private_key.public_key_openssh}"),
    ssh_private_key = base64gzip("${tls_private_key.keypair_private_key.private_key_openssh}"),
    hostname        = "gateway-api-${count.index}",
    username        = "${var.vm_username}",
    consul_version  = "${var.consul_version}"
  }))}"

  os_disk {
    name                 = "gateway-api-${count.index}-host-osdisk"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  admin_ssh_key {
    username   = "${var.vm_username}"
    public_key = "${tls_private_key.keypair_private_key.public_key_openssh}"
  }

  ## This should fix destroy issues
  depends_on = [ azurerm_network_interface_security_group_association.gateway-api-nic-sg-ass ]

}

#-------------#
#  MESH GW    #
#-------------#

resource "azurerm_network_interface" "gateway-mesh-nic" {
  count               = "${var.mesh_gw_number}"
  name                = "gateway-mesh-${count.index}-nic"
  location            = "${var.location}"
  resource_group_name = "${azurerm_resource_group.hashistack.name}"

  ip_configuration {
    name                          = "gateway-mesh-${count.index}-ipconfig"
    subnet_id                     = "${azurerm_subnet.hashistack-sn.id}"
    private_ip_address_allocation = "Dynamic"
  }

  tags                            = {"ConsulJoinTag" = "auto-join-${local.name_suffix}"}
}

resource "azurerm_network_interface_security_group_association" "gateway-mesh-nic-sg-ass" {
  count                     = "${var.mesh_gw_number}"
  network_interface_id      = "${element(azurerm_network_interface.gateway-mesh-nic.*.id, count.index)}"
  network_security_group_id = "${azurerm_network_security_group.consul-service.id}"
}

resource "azurerm_linux_virtual_machine" "gateway-mesh" {
  count                 = "${var.mesh_gw_number}"
  name                  = "gateway-mesh-${count.index}"
  location              = "${var.location}"
  resource_group_name   = "${azurerm_resource_group.hashistack.name}"
  network_interface_ids = [ "${element(azurerm_network_interface.gateway-mesh-nic.*.id, count.index)}" ]
  size                  = "Standard_B2s"

  # source_image_id       = "${data.azurerm_platform_image.debian.id}"

  source_image_reference {
    publisher = "${data.azurerm_platform_image.debian.publisher}"
    offer     = "${data.azurerm_platform_image.debian.offer}"
    sku       = "${data.azurerm_platform_image.debian.sku}"
    version   = "${data.azurerm_platform_image.debian.version}"
  }

  computer_name  = "gateway-mesh-${count.index}"
  admin_username = "${var.vm_username}"  

  user_data = "${base64encode(templatefile("${path.module}/../../../assets/templates/cloud-init/user_data_consul_agent.tmpl", {
    ssh_public_key  = base64gzip("${tls_private_key.keypair_private_key.public_key_openssh}"),
    ssh_private_key = base64gzip("${tls_private_key.keypair_private_key.private_key_openssh}"),
    hostname        = "gateway-mesh-${count.index}",
    username        = "${var.vm_username}",
    consul_version  = "${var.consul_version}"
  }))}"

  os_disk {
    name                 = "gateway-mesh-${count.index}-host-osdisk"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  admin_ssh_key {
    username   = "${var.vm_username}"
    public_key = "${tls_private_key.keypair_private_key.public_key_openssh}"
  }

  ## This should fix destroy issues
  depends_on = [ azurerm_network_interface_security_group_association.gateway-mesh-nic-sg-ass ]

}

#--------------------#
#  TERMINATING GW    #
#--------------------#

resource "azurerm_network_interface" "gateway-terminating-nic" {
  count               = "${var.term_gw_number}"
  name                = "gateway-terminating-${count.index}-nic"
  location            = "${var.location}"
  resource_group_name = "${azurerm_resource_group.hashistack.name}"

  ip_configuration {
    name                          = "gateway-terminating-${count.index}-ipconfig"
    subnet_id                     = "${azurerm_subnet.hashistack-sn.id}"
    private_ip_address_allocation = "Dynamic"
  }

  tags                            = {"ConsulJoinTag" = "auto-join-${local.name_suffix}"}
}

resource "azurerm_network_interface_security_group_association" "gateway-terminating-nic-sg-ass" {
  count                     = "${var.term_gw_number}"
  network_interface_id      = "${element(azurerm_network_interface.gateway-terminating-nic.*.id, count.index)}"
  network_security_group_id = "${azurerm_network_security_group.consul-service.id}"
}

resource "azurerm_linux_virtual_machine" "gateway-terminating" {
  count                 = "${var.term_gw_number}"
  name                  = "gateway-terminating-${count.index}"
  location              = "${var.location}"
  resource_group_name   = "${azurerm_resource_group.hashistack.name}"
  network_interface_ids = [ "${element(azurerm_network_interface.gateway-terminating-nic.*.id, count.index)}" ]
  size                  = "Standard_B2s"

  # source_image_id       = "${data.azurerm_platform_image.debian.id}"

  source_image_reference {
    publisher = "${data.azurerm_platform_image.debian.publisher}"
    offer     = "${data.azurerm_platform_image.debian.offer}"
    sku       = "${data.azurerm_platform_image.debian.sku}"
    version   = "${data.azurerm_platform_image.debian.version}"
  }

  computer_name  = "gateway-terminating-${count.index}"
  admin_username = "${var.vm_username}"  

  user_data = "${base64encode(templatefile("${path.module}/../../../assets/templates/cloud-init/user_data_consul_agent.tmpl", {
    ssh_public_key  = base64gzip("${tls_private_key.keypair_private_key.public_key_openssh}"),
    ssh_private_key = base64gzip("${tls_private_key.keypair_private_key.private_key_openssh}"),
    hostname        = "gateway-terminating-${count.index}",
    username        = "${var.vm_username}",
    consul_version  = "${var.consul_version}"
  }))}"

  os_disk {
    name                 = "gateway-terminating-${count.index}-host-osdisk"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  admin_ssh_key {
    username   = "${var.vm_username}"
    public_key = "${tls_private_key.keypair_private_key.public_key_openssh}"
  }

  ## This should fix destroy issues
  depends_on = [ azurerm_network_interface_security_group_association.gateway-terminating-nic-sg-ass ]

}


#----------------#
#  CONSUL ESM    #
#----------------#

resource "azurerm_network_interface" "consul-esm-nic" {
  count               = "${var.consul_esm_number}"
  name                = "consul-esm-${count.index}-nic"
  location            = "${var.location}"
  resource_group_name = "${azurerm_resource_group.hashistack.name}"

  ip_configuration {
    name                          = "consul-esm-${count.index}-ipconfig"
    subnet_id                     = "${azurerm_subnet.hashistack-sn.id}"
    private_ip_address_allocation = "Dynamic"
  }

  tags                            = {"ConsulJoinTag" = "auto-join-${local.name_suffix}"}
}

resource "azurerm_network_interface_security_group_association" "consul-esm-nic-sg-ass" {
  count                     = "${var.consul_esm_number}"
  network_interface_id      = "${element(azurerm_network_interface.consul-esm-nic.*.id, count.index)}"
  network_security_group_id = "${azurerm_network_security_group.consul-service.id}"
}

resource "azurerm_linux_virtual_machine" "consul-esm" {
  count                 = "${var.consul_esm_number}"
  name                  = "consul-esm-${count.index}"
  location              = "${var.location}"
  resource_group_name   = "${azurerm_resource_group.hashistack.name}"
  network_interface_ids = [ "${element(azurerm_network_interface.consul-esm-nic.*.id, count.index)}" ]
  size                  = "Standard_B2s"

  # source_image_id       = "${data.azurerm_platform_image.debian.id}"

  source_image_reference {
    publisher = "${data.azurerm_platform_image.debian.publisher}"
    offer     = "${data.azurerm_platform_image.debian.offer}"
    sku       = "${data.azurerm_platform_image.debian.sku}"
    version   = "${data.azurerm_platform_image.debian.version}"
  }

  computer_name  = "consul-esm-${count.index}"
  admin_username = "${var.vm_username}"  

  user_data = "${base64encode(templatefile("${path.module}/../../../assets/templates/cloud-init/user_data_consul_agent.tmpl", {
    ssh_public_key  = base64gzip("${tls_private_key.keypair_private_key.public_key_openssh}"),
    ssh_private_key = base64gzip("${tls_private_key.keypair_private_key.private_key_openssh}"),
    hostname        = "consul-esm-${count.index}",
    username        = "${var.vm_username}",
    consul_version  = "${var.consul_version}"
  }))}"

  os_disk {
    name                 = "consul-esm-${count.index}-host-osdisk"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  admin_ssh_key {
    username   = "${var.vm_username}"
    public_key = "${tls_private_key.keypair_private_key.public_key_openssh}"
  }

  ## This should fix destroy issues
  depends_on = [ azurerm_network_interface_security_group_association.consul-esm-nic-sg-ass ]

}