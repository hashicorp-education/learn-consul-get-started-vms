#------------------------------------------------------------------------------#
## Consul Server(s)
#------------------------------------------------------------------------------#

resource "azurerm_public_ip" "consul-server-pip" {
  count               = "${var.server_number}"
  name                = "consul-server-${count.index}-ip"
  location            = "${var.location}"
  resource_group_name = "${azurerm_resource_group.hashistack.name}"
  # allocation_method   = "Dynamic"
  allocation_method   = "Static"
}

resource "azurerm_network_interface" "consul-server-nic" {
  count               = "${var.server_number}"
  name                = "consul-server-${count.index}-nic"
  location            = "${var.location}"
  resource_group_name = "${azurerm_resource_group.hashistack.name}"

  ip_configuration {
    name                          = "consul-server-${count.index}-ipconfig"
    subnet_id                     = "${azurerm_subnet.hashistack-sn.id}"
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = "${element(azurerm_public_ip.consul-server-pip.*.id, count.index)}"
  }

  tags                            = {"ConsulJoinTag" = "auto-join-${local.name_suffix}"}
}

resource "azurerm_network_interface_security_group_association" "consul-server-nic-sg-ass" {
  count                     = "${var.server_number}"
  network_interface_id      = "${element(azurerm_network_interface.consul-server-nic.*.id, count.index)}"
  network_security_group_id = "${azurerm_network_security_group.consul-server.id}"
}

resource "azurerm_linux_virtual_machine" "consul-server" {
  count                 = "${var.server_number}"
  name                  = "consul-server-${count.index}"
  location              = "${var.location}"
  resource_group_name   = "${azurerm_resource_group.hashistack.name}"
  network_interface_ids = [ "${element(azurerm_network_interface.consul-server-nic.*.id, count.index)}" ]
  size                  = "Standard_B2s"

  # source_image_id       = "${data.azurerm_platform_image.debian.id}"

  source_image_reference {
    publisher = "${data.azurerm_platform_image.debian.publisher}"
    offer     = "${data.azurerm_platform_image.debian.offer}"
    sku       = "${data.azurerm_platform_image.debian.sku}"
    version   = "${data.azurerm_platform_image.debian.version}"
  }

  computer_name  = "consul-server-${count.index}"
  admin_username = "${var.vm_username}"  

  user_data = "${base64encode(templatefile("${path.module}/../../../assets/templates/cloud-init/user_data_consul_agent.tmpl", {
    ssh_public_key  = base64gzip("${tls_private_key.keypair_private_key.public_key_openssh}"),
    ssh_private_key = base64gzip("${tls_private_key.keypair_private_key.private_key_openssh}"),
    hostname        = "consul-server-${count.index}",
    username        = "${var.vm_username}",
    consul_version  = "${var.consul_version}"
  }))}"

  os_disk {
    name                 = "consul-server-${count.index}-host-osdisk"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  admin_ssh_key {
    username   = "${var.vm_username}"
    public_key = "${tls_private_key.keypair_private_key.public_key_openssh}"
  }

  connection {
    type        = "ssh"
    user        = "${var.vm_username}"
    private_key = "${tls_private_key.keypair_private_key.private_key_pem}"
    host        = self.public_ip_address
  }

  # Waits for cloud-init to complete. Needed for ACL creation.
  provisioner "remote-exec" {
    inline = [
      "echo 'Waiting for user data script to finish'",
      "cloud-init status --wait > /dev/null"
    ]
  }

  ## This should fix destroy issues
  depends_on = [ azurerm_network_interface_security_group_association.consul-server-nic-sg-ass ]

}