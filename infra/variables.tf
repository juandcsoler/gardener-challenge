variable "aws_region" {
  description = "AWS region to deploy the Gardener dev-box into."
  type        = string
  default     = "eu-west-1"
}

variable "instance_type" {
  description = "EC2 instance type. Gardener's docs require >= 8 CPU / 8Gi RAM for one Seed + one Shoot; m5.2xlarge (8 vCPU/32Gi) gives comfortable headroom."
  type        = string
  default     = "m5.2xlarge"
}

variable "root_volume_size_gb" {
  description = "Root EBS volume size in GB. Gardener's docs recommend >= 120Gi for image/layer storage."
  type        = number
  default     = 200
}

variable "allowed_ssh_cidr" {
  description = "CIDR allowed to SSH into the box, e.g. \"203.0.113.4/32\". Keep this scoped to your own IP — do not use 0.0.0.0/0."
  type        = string
}

variable "public_key_path" {
  description = "Path to a local SSH public key file to install on the instance (e.g. ~/.ssh/id_ed25519.pub)."
  type        = string
}

variable "name_prefix" {
  description = "Prefix used to name/tag all resources."
  type        = string
  default     = "gardener-challenge"
}
