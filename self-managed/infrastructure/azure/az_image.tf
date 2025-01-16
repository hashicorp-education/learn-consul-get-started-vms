#  https://az-vm-image.info/?cmd=--all+--publisher+Debian+--offer+debian-12

data "azurerm_platform_image" "debian" {
  location  = "${var.location}"
  publisher = "Debian"
  offer     = "debian-12"
  sku       = "12"
}