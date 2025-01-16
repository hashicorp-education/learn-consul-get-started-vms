#------------------------------------------------------------------------------#
## Bastion host
#------------------------------------------------------------------------------#

locals {
  # bastion_fake_dns = ""
  bastion_fake_dns = <<EOF
# There should always be at least one Consul server
${azurerm_linux_virtual_machine.consul-server.0.private_ip_address} consul server.${var.consul_datacenter}.${var.consul_domain}
%{ for index, ip in azurerm_linux_virtual_machine.consul-server.*.private_ip_address ~}
${ip} consul-server-${index} 
%{ endfor ~}
# The following lines are added for hashicups scenario
%{ for index, ip in azurerm_linux_virtual_machine.hashicups-db.*.private_ip_address ~}
${ip} hashicups-db-${index} 
%{ endfor ~}
%{ for index, ip in azurerm_linux_virtual_machine.hashicups-api.*.private_ip_address ~}
${ip} hashicups-api-${index} 
%{ endfor ~}
%{ for index, ip in azurerm_linux_virtual_machine.hashicups-frontend.*.private_ip_address ~}
${ip} hashicups-frontend-${index} 
%{ endfor ~}
%{ for index, ip in azurerm_linux_virtual_machine.hashicups-nginx.*.private_ip_address ~}
${ip} hashicups-nginx-${index} hashicups-lb-${index} 
%{ endfor ~}
%{ for index, ip in azurerm_linux_virtual_machine.gateway-api.*.private_ip_address ~}
${ip} gateway-api-${index} 
%{ endfor ~}
%{ for index, ip in azurerm_linux_virtual_machine.gateway-mesh.*.private_ip_address ~}
${ip} gateway-mesh-${index} 
%{ endfor ~}
%{ for index, ip in azurerm_linux_virtual_machine.gateway-terminating.*.private_ip_address ~}
${ip} gateway-terminating-${index} 
%{ endfor ~}
%{ for index, ip in azurerm_linux_virtual_machine.consul-esm.*.private_ip_address ~}
${ip} consul-esm-${index} 
%{ endfor ~}
%{ if  length(azurerm_linux_virtual_machine.gateway-api) >= "1" }${azurerm_linux_virtual_machine.gateway-api.0.public_ip_address}  gateway-api-public gw-api-public%{ else }""%{ endif }
  EOF
}

resource "azurerm_public_ip" "bastion-pip" {
  name                = "bastion-ip"
  location            = "${var.location}"
  resource_group_name = "${azurerm_resource_group.hashistack.name}"
  # allocation_method   = "Dynamic"
  allocation_method   = "Static"
}

resource "azurerm_network_interface" "bastion-nic" {
  name                = "bastion-nic"
  location            = "${var.location}"
  resource_group_name = "${azurerm_resource_group.hashistack.name}"

  ip_configuration {
    name                          = "bastion-ipconfig"
    subnet_id                     = "${azurerm_subnet.hashistack-sn.id}"
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = "${azurerm_public_ip.bastion-pip.id}"
  }
}

resource "azurerm_network_interface_security_group_association" "bastion-nic-sg-ass" {
  network_interface_id      = "${azurerm_network_interface.bastion-nic.id}"
  network_security_group_id = "${azurerm_network_security_group.bastion-host.id}"
}

resource "azurerm_linux_virtual_machine" "bastion" {
  name                  = "bastion-host"
  location              = "${var.location}"
  resource_group_name   = "${azurerm_resource_group.hashistack.name}"
  network_interface_ids = [ "${azurerm_network_interface.bastion-nic.id}" ]
  size                  = "Standard_B2s"

  # source_image_id       = "${data.azurerm_platform_image.debian.id}"

  source_image_reference {
    publisher = "${data.azurerm_platform_image.debian.publisher}"
    offer     = "${data.azurerm_platform_image.debian.offer}"
    sku       = "${data.azurerm_platform_image.debian.sku}"
    version   = "${data.azurerm_platform_image.debian.version}"
  }

  computer_name  = "bastion"
  admin_username = "${var.vm_username}"  

  user_data = "${base64encode(templatefile("${path.module}/../../../assets/templates/cloud-init/user_data_bastion.tmpl", {
    ssh_public_key  = base64gzip("${tls_private_key.keypair_private_key.public_key_openssh}"),
    ssh_private_key = base64gzip("${tls_private_key.keypair_private_key.private_key_openssh}"),
    hostname        = "bastion",
    username        = "${var.vm_username}",
    consul_version  = "${var.consul_version}",
    HOSTS_EXTRA_CONFIG = base64gzip("${local.bastion_fake_dns}")
  }))}"

  os_disk {
    name                 = "bastion-host-osdisk"
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

  provisioner "file" {
    source      = "${path.module}/../../../assets"
    destination = "/home/${var.vm_username}/"
  }

  provisioner "file" {
    source      = "${path.module}/../../ops"
    destination = "/home/${var.vm_username}"
  }

  # Waits for cloud-init to complete. Needed for ACL creation.
  provisioner "remote-exec" {
    inline = [
      "echo 'Waiting for user data script to finish'",
      "cloud-init status --wait > /dev/null", 
      "cd /home/${var.vm_username}/ops && bash ./provision.sh operate ${var.scenario}"
    ]
  }

  ## This should fix destroy issues
  depends_on = [ azurerm_network_interface_security_group_association.bastion-nic-sg-ass ]
}