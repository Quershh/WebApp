variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "eu-west-2"
}

variable "ssh_allowed_ip" {
  description = "IP allowed to SSH into EC2"
  type        = string
}
