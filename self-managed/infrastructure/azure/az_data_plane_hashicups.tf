

#------------------------------------------------------------------------------#
## HashiCups
#------------------------------------------------------------------------------#

#------------#
#  DATABASE  #
#------------#

resource "azurerm_network_interface" "hashicups-db-nic" {
  count               = "${var.hc_db_number}"
  name                = "hashicups-db-${count.index}-nic"
  location            = "${var.location}"
  resource_group_name = "${azurerm_resource_group.hashistack.name}"

  ip_configuration {
    name                          = "hashicups-db-${count.index}-ipconfig"
    subnet_id                     = "${azurerm_subnet.hashistack-sn.id}"
    private_ip_address_allocation = "Dynamic"
  }

  tags                            = {"ConsulJoinTag" = "auto-join-${local.name_suffix}"}
}

resource "azurerm_network_interface_security_group_association" "hashicups-db-nic-sg-ass" {
  count                     = "${var.hc_db_number}"
  network_interface_id      = "${element(azurerm_network_interface.hashicups-db-nic.*.id, count.index)}"
  network_security_group_id = "${azurerm_network_security_group.consul-service.id}"
}

resource "azurerm_linux_virtual_machine" "hashicups-db" {
  count                 = "${var.hc_db_number}"
  name                  = "hashicups-db-${count.index}"
  location              = "${var.location}"
  resource_group_name   = "${azurerm_resource_group.hashistack.name}"
  network_interface_ids = [ "${element(azurerm_network_interface.hashicups-db-nic.*.id, count.index)}" ]
  size                  = "Standard_B2s"

  # source_image_id       = "${data.azurerm_platform_image.debian.id}"

  source_image_reference {
    publisher = "${data.azurerm_platform_image.debian.publisher}"
    offer     = "${data.azurerm_platform_image.debian.offer}"
    sku       = "${data.azurerm_platform_image.debian.sku}"
    version   = "${data.azurerm_platform_image.debian.version}"
  }

  computer_name  = "hashicups-db-${count.index}"
  admin_username = "${var.vm_username}"  

  user_data = "${base64encode(templatefile("${path.module}/../../../assets/templates/cloud-init/user_data_consul_agent.tmpl", {
    ssh_public_key  = base64gzip("${tls_private_key.keypair_private_key.public_key_openssh}"),
    ssh_private_key = base64gzip("${tls_private_key.keypair_private_key.private_key_openssh}"),
    hostname        = "hashicups-db-${count.index}",
    username        = "${var.vm_username}",
    consul_version  = "${var.consul_version}"
  }))}"

  os_disk {
    name                 = "hashicups-db-${count.index}-host-osdisk"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  admin_ssh_key {
    username   = "${var.vm_username}"
    public_key = "${tls_private_key.keypair_private_key.public_key_openssh}"
  }

  ## This should fix destroy issues
  depends_on = [ azurerm_network_interface_security_group_association.hashicups-db-nic-sg-ass ]

}


#------------#
#    API     #
#------------#

resource "azurerm_network_interface" "hashicups-api-nic" {
  count               = "${var.hc_api_number}"
  name                = "hashicups-api-${count.index}-nic"
  location            = "${var.location}"
  resource_group_name = "${azurerm_resource_group.hashistack.name}"

  ip_configuration {
    name                          = "hashicups-api-${count.index}-ipconfig"
    subnet_id                     = "${azurerm_subnet.hashistack-sn.id}"
    private_ip_address_allocation = "Dynamic"
  }

  tags                            = {"ConsulJoinTag" = "auto-join-${local.name_suffix}"}
}

resource "azurerm_network_interface_security_group_association" "hashicups-api-nic-sg-ass" {
  count                     = "${var.hc_api_number}"
  network_interface_id      = "${element(azurerm_network_interface.hashicups-api-nic.*.id, count.index)}"
  network_security_group_id = "${azurerm_network_security_group.consul-service.id}"
}

resource "azurerm_linux_virtual_machine" "hashicups-api" {
  count                 = "${var.hc_api_number}"
  name                  = "hashicups-api-${count.index}"
  location              = "${var.location}"
  resource_group_name   = "${azurerm_resource_group.hashistack.name}"
  network_interface_ids = [ "${element(azurerm_network_interface.hashicups-api-nic.*.id, count.index)}" ]
  size                  = "Standard_B2s"

  # source_image_id       = "${data.azurerm_platform_image.debian.id}"

  source_image_reference {
    publisher = "${data.azurerm_platform_image.debian.publisher}"
    offer     = "${data.azurerm_platform_image.debian.offer}"
    sku       = "${data.azurerm_platform_image.debian.sku}"
    version   = "${data.azurerm_platform_image.debian.version}"
  }

  computer_name  = "hashicups-api-${count.index}"
  admin_username = "${var.vm_username}"  

  user_data = "${base64encode(templatefile("${path.module}/../../../assets/templates/cloud-init/user_data_consul_agent.tmpl", {
    ssh_public_key  = base64gzip("${tls_private_key.keypair_private_key.public_key_openssh}"),
    ssh_private_key = base64gzip("${tls_private_key.keypair_private_key.private_key_openssh}"),
    hostname        = "hashicups-api-${count.index}",
    username        = "${var.vm_username}",
    consul_version  = "${var.consul_version}"
  }))}"

  os_disk {
    name                 = "hashicups-api-${count.index}-host-osdisk"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  admin_ssh_key {
    username   = "${var.vm_username}"
    public_key = "${tls_private_key.keypair_private_key.public_key_openssh}"
  }

  ## This should fix destroy issues
  depends_on = [ azurerm_network_interface_security_group_association.hashicups-api-nic-sg-ass ]
}


#------------#
#  FRONTEND  #
#------------#

resource "azurerm_network_interface" "hashicups-frontend-nic" {
  count               = "${var.hc_fe_number}"
  name                = "hashicups-frontend-${count.index}-nic"
  location            = "${var.location}"
  resource_group_name = "${azurerm_resource_group.hashistack.name}"

  ip_configuration {
    name                          = "hashicups-frontend-${count.index}-ipconfig"
    subnet_id                     = "${azurerm_subnet.hashistack-sn.id}"
    private_ip_address_allocation = "Dynamic"
  }

  tags                            = {"ConsulJoinTag" = "auto-join-${local.name_suffix}"}
}

resource "azurerm_network_interface_security_group_association" "hashicups-frontend-nic-sg-ass" {
  count                     = "${var.hc_fe_number}"
  network_interface_id      = "${element(azurerm_network_interface.hashicups-frontend-nic.*.id, count.index)}"
  network_security_group_id = "${azurerm_network_security_group.consul-service.id}"
}

resource "azurerm_linux_virtual_machine" "hashicups-frontend" {
  count                 = "${var.hc_fe_number}"
  name                  = "hashicups-frontend-${count.index}"
  location              = "${var.location}"
  resource_group_name   = "${azurerm_resource_group.hashistack.name}"
  network_interface_ids = [ "${element(azurerm_network_interface.hashicups-frontend-nic.*.id, count.index)}" ]
  size                  = "Standard_B2s"

  # source_image_id       = "${data.azurerm_platform_image.debian.id}"

  source_image_reference {
    publisher = "${data.azurerm_platform_image.debian.publisher}"
    offer     = "${data.azurerm_platform_image.debian.offer}"
    sku       = "${data.azurerm_platform_image.debian.sku}"
    version   = "${data.azurerm_platform_image.debian.version}"
  }

  computer_name  = "hashicups-frontend-${count.index}"
  admin_username = "${var.vm_username}"  

  user_data = "${base64encode(templatefile("${path.module}/../../../assets/templates/cloud-init/user_data_consul_agent.tmpl", {
    ssh_public_key  = base64gzip("${tls_private_key.keypair_private_key.public_key_openssh}"),
    ssh_private_key = base64gzip("${tls_private_key.keypair_private_key.private_key_openssh}"),
    hostname        = "hashicups-frontend-${count.index}",
    username        = "${var.vm_username}",
    consul_version  = "${var.consul_version}"
  }))}"

  os_disk {
    name                 = "hashicups-frontend-${count.index}-host-osdisk"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  admin_ssh_key {
    username   = "${var.vm_username}"
    public_key = "${tls_private_key.keypair_private_key.public_key_openssh}"
  }

  ## This should fix destroy issues
  depends_on = [ azurerm_network_interface_security_group_association.hashicups-frontend-nic-sg-ass ]

}

#------------#
#   NGINX    #
#------------#

resource "azurerm_public_ip" "hashicups-nginx-pip" {
  count               = "${var.hc_lb_number}"
  name                = "hashicups-nginx-${count.index}-ip"
  location            = "${var.location}"
  resource_group_name = "${azurerm_resource_group.hashistack.name}"
  # allocation_method   = "Dynamic"
  allocation_method   = "Static"
}

resource "azurerm_network_interface" "hashicups-nginx-nic" {
  count               = "${var.hc_lb_number}"
  name                = "hashicups-nginx-${count.index}-nic"
  location            = "${var.location}"
  resource_group_name = "${azurerm_resource_group.hashistack.name}"

  ip_configuration {
    name                          = "hashicups-nginx-${count.index}-ipconfig"
    subnet_id                     = "${azurerm_subnet.hashistack-sn.id}"
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = "${element(azurerm_public_ip.hashicups-nginx-pip.*.id, count.index)}"
  }

  tags                            = {"ConsulJoinTag" = "auto-join-${local.name_suffix}"}
}

resource "azurerm_network_interface_security_group_association" "hashicups-nginx-nic-sg-ass" {
  count                     = "${var.hc_lb_number}"
  network_interface_id      = "${element(azurerm_network_interface.hashicups-nginx-nic.*.id, count.index)}"
  network_security_group_id = "${azurerm_network_security_group.consul-service.id}"
}

resource "azurerm_linux_virtual_machine" "hashicups-nginx" {
  count                 = "${var.hc_lb_number}"
  name                  = "hashicups-nginx-${count.index}"
  location              = "${var.location}"
  resource_group_name   = "${azurerm_resource_group.hashistack.name}"
  network_interface_ids = [ "${element(azurerm_network_interface.hashicups-nginx-nic.*.id, count.index)}" ]
  size                  = "Standard_B2s"

  # source_image_id       = "${data.azurerm_platform_image.debian.id}"

  source_image_reference {
    publisher = "${data.azurerm_platform_image.debian.publisher}"
    offer     = "${data.azurerm_platform_image.debian.offer}"
    sku       = "${data.azurerm_platform_image.debian.sku}"
    version   = "${data.azurerm_platform_image.debian.version}"
  }

  computer_name  = "hashicups-nginx-${count.index}"
  admin_username = "${var.vm_username}"  

  user_data = "${base64encode(templatefile("${path.module}/../../../assets/templates/cloud-init/user_data_consul_agent.tmpl", {
    ssh_public_key  = base64gzip("${tls_private_key.keypair_private_key.public_key_openssh}"),
    ssh_private_key = base64gzip("${tls_private_key.keypair_private_key.private_key_openssh}"),
    hostname        = "hashicups-nginx-${count.index}",
    username        = "${var.vm_username}",
    consul_version  = "${var.consul_version}"
  }))}"

  os_disk {
    name                 = "hashicups-nginx-${count.index}-host-osdisk"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  admin_ssh_key {
    username   = "${var.vm_username}"
    public_key = "${tls_private_key.keypair_private_key.public_key_openssh}"
  }

  ## This should fix destroy issues
  depends_on = [ azurerm_network_interface_security_group_association.hashicups-nginx-nic-sg-ass ]

}
