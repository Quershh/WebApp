terraform {
  backend "s3" {
    bucket         = "devsecops-terraform-webapp-state-708426825297"
    key            = "infra/terraform.tfstate"
    region         = "eu-west-2"
    dynamodb_table = "devsecops-terraform-webapp-locks"
    encrypt        = true
  }

  required_version = ">= 1.3.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}


provider "aws" {
  region = var.aws_region
}


resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "devsecops-vpc"
  }
}

#checkov:skip=CKV_AWS_130: "Intentionally public subnet for demo web app; production would use private subnets + ALB/NAT/SSM."
resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true

  tags = {
    Name = "public-subnet"
  }
}


resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "devsecops-igw"
  }
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "public-rt"
  }
}

resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_security_group" "web_sg" {
  name        = "devsecops-web-sg"
  description = "Security group for web server"
  vpc_id      = aws_vpc.main.id

  #checkov:skip=CKV_AWS_260: "Demo web app intentionally exposed on HTTP; in production will use ALB/WAF/HTTPS and private subnets."
  ingress {
  description = "HTTP (demo)"
  from_port   = 80
  to_port     = 80
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
}

  egress {
  description = "Allow outbound HTTP/HTTPS and DNS"
  from_port   = 443
  to_port     = 443
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
}

egress {
  description = "Allow outbound HTTP"
  from_port   = 80
  to_port     = 80
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
}

egress {
  description = "Allow DNS (UDP)"
  from_port   = 53
  to_port     = 53
  protocol    = "udp"
  cidr_blocks = ["0.0.0.0/0"]
}

egress {
  description = "Allow DNS (TCP)"
  from_port   = 53
  to_port     = 53
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
}


  tags = {
    Name = "devsecops-web-sg"
  }
}

resource "aws_default_security_group" "default" {
  vpc_id = aws_vpc.main.id

  # No ingress / no egress rules = locked down
  ingress = []
  egress  = []

  tags = {
    Name = "devsecops-default-sg-locked"
  }
}


data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

#checkov:skip=CKV_AWS_135: "t2.micro used for cost/free-tier demo; EBS optimization not applicable/meaningful for this instance type."
resource "aws_instance" "web_server" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.public_subnet.id
  vpc_security_group_ids = [aws_security_group.web_sg.id]

  # CKV_AWS_126
  monitoring = true

  # CKV_AWS_79 (IMDSv2) Protects against SSRF attacks and others 
  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  # CKV_AWS_8 (EBS encryption)
  root_block_device {
    encrypted = true
  }

  # CKV2_AWS_41 (IAM role attached) – 
  iam_instance_profile = aws_iam_instance_profile.ec2_profile.name

  user_data = <<-EOF
    #!/bin/bash
    yum update -y
    yum install -y python3 git
    pip3 install flask
    cat << 'APP' > /home/ec2-user/app.py
    from flask import Flask
    app = Flask(__name__)
    @app.route("/")
    def hello():
        return "Hello from a hardened DevSecOps EC2 instance!"
    if __name__ == "__main__":
        app.run(host="127.0.0.1", port=80)
    APP
    python3 /home/ec2-user/app.py &
  EOF

  tags = {
    Name = "devsecops-web-ec2"
  }
}

data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ec2_role" {
  name               = "devsecops-ec2-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.ec2_role.name
  policy_arn  = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "devsecops-ec2-profile"
  role = aws_iam_role.ec2_role.name
}

resource "aws_cloudwatch_log_group" "vpc_flow_logs" {
  name              = "/aws/vpc/devsecops-flow-logs"
  retention_in_days = 365

}

data "aws_iam_policy_document" "flow_logs_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["vpc-flow-logs.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "flow_logs_role" {
  name               = "devsecops-vpc-flow-logs-role"
  assume_role_policy = data.aws_iam_policy_document.flow_logs_assume_role.json
}

data "aws_iam_policy_document" "flow_logs_policy" {
  statement {
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams"
    ]
    resources = ["${aws_cloudwatch_log_group.vpc_flow_logs.arn}:*"]
  }
}

resource "aws_iam_role_policy" "flow_logs_role_policy" {
  name   = "devsecops-vpc-flow-logs-policy"
  role   = aws_iam_role.flow_logs_role.id
  policy = data.aws_iam_policy_document.flow_logs_policy.json
}

resource "aws_flow_log" "vpc" {
  vpc_id               = aws_vpc.main.id
  traffic_type         = "ALL"
  log_destination_type = "cloud-watch-logs"
  log_destination      = aws_cloudwatch_log_group.vpc_flow_logs.arn
  iam_role_arn         = aws_iam_role.flow_logs_role.arn
}

data "aws_iam_policy_document" "kms_key_policy" {

  # Allow account root to administer the key (but not wildcard kms:*)
  statement {
    sid    = "AllowKeyAdministration"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }

    actions = [
      "kms:Create*",
      "kms:Describe*",
      "kms:Enable*",
      "kms:List*",
      "kms:Put*",
      "kms:Update*",
      "kms:Revoke*",
      "kms:Disable*",
      "kms:Get*",
      "kms:Delete*",
      "kms:ScheduleKeyDeletion",
      "kms:CancelKeyDeletion"
    ]

    resources = ["*"]
  }

  # Allow CloudWatch Logs to use the key
 statement {
  sid    = "AllowCloudWatchLogsUsage"
  effect = "Allow"

  principals {
    type        = "Service"
    identifiers = ["logs.eu-west-2.amazonaws.com"]
  }

  actions = [
    "kms:Encrypt",
    "kms:Decrypt",
    "kms:ReEncrypt*",
    "kms:GenerateDataKey*",
    "kms:DescribeKey",
    "kms:CreateGrant"
  ]

  resources = ["*"]

  condition {
    test     = "Bool"
    variable = "kms:GrantIsForAWSResource"
    values   = ["true"]
  }

  condition {
    test     = "ArnLike"
    variable = "kms:EncryptionContext:aws:logs:arn"
    values   = [
      "arn:aws:logs:eu-west-2:${data.aws_caller_identity.current.account_id}:log-group:*"
    ]
  }
}


}


data "aws_caller_identity" "current" {}

resource "aws_kms_key" "cw_logs" {
  description             = "KMS key for CloudWatch Logs encryption (DevSecOps project)"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  policy                  = data.aws_iam_policy_document.kms_key_policy.json
}


resource "aws_kms_alias" "cw_logs_alias" {
  name          = "alias/devsecops-cw-logs"
  target_key_id = aws_kms_key.cw_logs.key_id
}

