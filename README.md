# DevSecOps AWS Web Application (Terraform + GitHub Actions)

## Overview
This project demonstrates an end-to-end **DevSecOps workflow** using AWS, Terraform, and GitHub Actions.

It covers:
- Infrastructure as Code (IaC)
- Security scanning (IaC, dependencies, and code)
- Secure Continuous Deployment (CD) using GitHub Actions with AWS OIDC
- Remote Terraform state management

The project is designed as a **learning and portfolio project** and reflects real-world DevSecOps patterns and trade-offs.

---

## Architecture
- AWS VPC with public subnet
- EC2 instance running a simple Flask web application
- Security groups with restricted ingress
- VPC Flow Logs enabled
- Terraform remote state stored in S3 with DynamoDB locking
- GitHub Actions CD pipeline using AWS OIDC (no long-lived credentials)

---

## Technologies Used
- **AWS**: EC2, VPC, IAM, CloudWatch, S3, DynamoDB
- **Terraform**: Infrastructure provisioning and state management
- **GitHub Actions**: Continuous Deployment
- **Python / Flask**: Sample web application
- **Security Tools**:
  - Checkov (IaC scanning)
  - pip-audit (dependency scanning)
  - Bandit (static code analysis)

---

## Infrastructure as Code (Terraform)
Infrastructure is fully defined using Terraform.

### Key Features
- Remote state backend (S3 + DynamoDB)
- State locking to prevent concurrent deployments
- IAM role for GitHub Actions using OIDC
- Security hardening (IMDSv2, encrypted EBS, IAM roles)

---

## Security Scanning

### IaC Scanning (Checkov)
Terraform code is scanned using Checkov.

Some findings are **intentionally skipped** with justification:
- Public subnet required for demo accessibility
- EC2 EBS optimization not applicable to free-tier instance types
- KMS policy findings due to AWS-required wildcard resources

These decisions are documented and would be handled differently in production.

---

### Dependency Scanning (pip-audit)
Python dependencies are pinned and scanned for known vulnerabilities.

Result:
- No known vulnerabilities found at the time of scanning

---

### Static Code Analysis (Bandit)
The Flask application code is scanned using Bandit.

One finding (binding to all interfaces) was identified and remediated by:
- Binding the application to localhost
- Relying on AWS networking controls for exposure

---

## Continuous Deployment (CD)

### GitHub Actions
A GitHub Actions workflow automatically deploys infrastructure on pushes to the `main` branch.

Key characteristics:
- Uses AWS OIDC for authentication
- No stored AWS access keys
- Runs `terraform init`, `plan`, and `apply`
- Uses remote Terraform state

---

## Known Limitations / Trade-offs

### CloudWatch Logs Encryption
An attempt was made to encrypt CloudWatch Logs with a customer-managed KMS key.

Due to a known AWS race condition involving KMS grant propagation during log group creation, AWS-managed encryption is currently used instead.

This trade-off is documented intentionally. In a production environment, alternative patterns (pre-created log groups or separate encryption workflows) would be used.

---

## Roadmap / Planned Enhancements
The following improvements are planned:
- CI pipeline for pull requests (Terraform plan + security scans)
- Dockerisation of the application
- Container image scanning (Trivy)
- Removal of SSH access using AWS SSM
- Application Load Balancer + HTTPS
- Manual approval gates for production deployments

---

## Disclaimer
This project is for learning and demonstration purposes.  
Some configurations are intentionally simplified for clarity and cost control.

quick update