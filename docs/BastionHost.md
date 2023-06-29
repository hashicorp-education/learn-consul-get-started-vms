[Home](../README.md)

# Bastion Host

The scenario deployment is based on the existence of a VM with SSH server 
installed and which has networking access via SSH to all other VMs.

The Bastion Host is equipped with all the tools necessary for the scenario 
deployment so it is not needed to have the tools on your local machine.

## Bastion Host Specs

The following tools are installed on the bastion host:

Base Packages: `apt-transport-https` `ca-certificates` `curl` `gnupg-agent` `software-properties-common` `jq` `dnsutils` `tree` 










```
 TF_OPS=""; for i in `terraform state list | grep --color=never aws_instance.bastion`; do TF_OPS="${TF_OPS} --target=$i"; done; terraform destroy -auto-approve $TF_OPS && terraform apply --auto-approve
 ```

