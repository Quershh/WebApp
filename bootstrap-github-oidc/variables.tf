variable "aws_region" {
  type    = string
  default = "eu-west-2"
}

variable "github_owner" {
  description = "GitHub org/user, e.g. callumharman"
  type        = string
}

variable "github_repo" {
  description = "GitHub repo name, e.g. devsecops-ec2-webapp"
  type        = string
}

variable "github_branch" {
  description = "Branch allowed to deploy (usually main)"
  type        = string
  default     = "main"
}
