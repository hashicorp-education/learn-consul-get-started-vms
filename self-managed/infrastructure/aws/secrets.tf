#------------------------------------------------------------------------------#
# Key/Cert for SSH connection to the hosts
#------------------------------------------------------------------------------#
resource "tls_private_key" "keypair_private_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "keypair" {
  key_name   = "id_rsa.pub.${local.name}"
  public_key = tls_private_key.keypair_private_key.public_key_openssh

  # Create "id_rsa.pem" in local directory
  provisioner "local-exec" {
    command = "rm -rf certs/id_rsa.pem && mkdir -p certs &&  echo '${tls_private_key.keypair_private_key.private_key_pem}' > certs/id_rsa.pem && chmod 400 certs/id_rsa.pem"
  }
}
