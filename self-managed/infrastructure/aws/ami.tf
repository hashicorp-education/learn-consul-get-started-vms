#------------------------------------------------------------------------------#
## AMI(s)
#------------------------------------------------------------------------------#

# # Debian 11 Bullseye AMI
# data "aws_ami" "debian-11" {
#   most_recent = true
#   owners      = ["136693071363"]
#   filter {
#     name   = "name"
#     values = ["debian-11-amd64-*"]
#   }
#   filter {
#     name   = "virtualization-type"
#     values = ["hvm"]
#   }
# }

# Debian 12 Bookworm AMI
data "aws_ami" "debian-12" {
  most_recent = true
  owners      = ["136693071363"]
  filter {
    name   = "name"
    values = ["debian-12-amd64-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}