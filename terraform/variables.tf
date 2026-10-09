# No defaults on purpose: every value must be set in terraform.tfvars
# (see terraform.tfvars.example).

variable "aws_region" {
  description = "AWS region for all resources."
  type        = string
}

variable "project_name" {
  description = "Short name used as a prefix for resources and tags."
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)."
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
}

variable "public_subnet_cidr" {
  description = "CIDR block for the public subnet (must be inside vpc_cidr)."
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type for both nodes (x86_64, because the AMI lookup is amd64)."
  type        = string
}

variable "root_volume_size_gb" {
  description = "Root EBS volume size in GiB."
  type        = number
}

variable "ssh_public_key_path" {
  description = "Path to the SSH public key uploaded as the EC2 key pair."
  type        = string
}

variable "ssh_private_key_path" {
  description = "Path to the matching private key. Terraform reads it once and hands it to the control node so Ansible can reach the managed node."
  type        = string
}

variable "admin_cidrs" {
  description = "CIDRs allowed to SSH to the nodes, e.g. [\"203.0.113.10/32\"]. 0.0.0.0/0 is rejected."
  type        = list(string)

  validation {
    condition     = length(var.admin_cidrs) > 0 && alltrue([for c in var.admin_cidrs : can(cidrnetmask(c)) && c != "0.0.0.0/0"])
    error_message = "admin_cidrs must be a non-empty list of valid IPv4 CIDRs and must not contain 0.0.0.0/0."
  }
}

variable "http_ingress_cidrs" {
  description = "CIDRs allowed to reach Nginx on the control node, port 80."
  type        = list(string)
}
