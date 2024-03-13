variable "allowed-source-ip" {
  description = "Your IP address to allow traffic from in CIDR notation."
}

variable "hcp_project_id" {
  description = "HCP Project ID (UUID)"
}

variable "hvn_route_id" {
  description = "The ID of the HCP HVN route."
  type        = string
  default     = "hcp-hvn-route"
}

variable "ssh_username" {
  type    = string
  default = "ubuntu"
}

locals {
  private_key_filename = "bastion-ssh-key.pem"
}

variable "ip_cidr_hvn" {
  description = "IP CIDR for HashiCorp Virtual Network"
  default     = "172.25.16.0/20"
}


variable "hcp_region" {
  description = "The region where the resources are created."
  default     = "us-west-2"
}

variable "aws_region" {
  description = "The region where the resources are created."
  default     = "us-west-2"
}

variable "address_space" {
  description = "The address space that is used by the virtual network. You can supply more than one address space. Changing this forces a new resource to be created."
  default     = "10.0.0.0/16"
}

variable "subnet_prefix" {
  description = "The address prefix to use for the subnet."
  default     = "10.0.10.0/24"
}

variable "instance_type" {
  description = "Specifies the AWS instance type."
  default     = "t3a.small"
}

variable "hcp_vault_tier" {
  default     = "dev"
  description = "HCP Vault tier"
}

variable "hcp_vault_public" {
  default     = false
  description = "Make HCP Vault cluster public"
}

variable "db_instance_type" {
  type    = string
  default = "m5.xlarge"
}

variable "prefix" {
  type    = string
  default = "example"
}

variable "mysql_dbname" {
  type    = string
  default = "sedemovaultdb"
}

variable "db_user" {
  type    = string
  default = "root"
}
