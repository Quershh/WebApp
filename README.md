# DevSecOps AWS Web Application (Terraform + GitHub Actions)

## Overview
This project demonstrates an end-to-end **DevSecOps workflow** using AWS, Terraform, Docker, and GitHub Actions.

It covers:
- Infrastructure as Code (IaC)
- Security scanning (IaC, dependencies, code, and containers)
- CI for pull requests with enforced security checks
- Secure Continuous Deployment (CD) using GitHub Actions with AWS OIDC
- Remote Terraform state management

The project is designed as a **learning and portfolio project** and reflects real-world DevSecOps patterns, decisions, and trade-offs.

---

## Architecture
- AWS VPC with public subnet
- EC2 instance provisioned via Terraform
- Dockerised Flask web application
- Security groups with restricted ingress
- VPC Flow Logs enabled
- Terraform remote state stored in S3 with DynamoDB locking
- GitHub Actions CI/CD pipelines using AWS OIDC (no long-lived credentials)

---

## Technologies Used
- **AWS**: EC2, VPC, IAM, CloudWatch, S3, DynamoDB
- **Terraform**: Infrastructure provisioning and state management
- **Docker**: Application containerisation
- **GitHub Actions**: CI and CD pipelines
- **Python / Flask**: Sample web application
- **Security Tools**:
  - Checkov (IaC scanning)
  - pip-audit (dependency scanning)
  - Bandit (static code analysis)
  - Trivy (container image scanning)

---

## Infrastructure as Code (Terraform)
Infrastructure is fully defined using Terraform.

### Key Features
- Remote state backend (S3 + DynamoDB)
- State locking to prevent concurrent deployments
- IAM role for GitHub Actions using OIDC
- Security hardening (IMDSv2, encrypted EBS, IAM roles)

---

## Containerisation
The application is containerised using **Docker** to ensure consistency between local development and CI environments.

### Key Characteristics
- Lightweight Python base image
- `.dockerignore` to reduce image size and attack surface
- Explicit port exposure
- Application runs on port `8080`

### Build and Run Locally

docker build -t devsecops-web ./app
docker run -p 8080:8080 devsecops-web

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
The Flask application code is scanned using Bandit as part of the CI pipeline.

One finding was identified:
- Binding to all network interfaces (0.0.0.0)

This behaviour is required for Docker container networking and is therefore:
- Explicitly suppressed using an inline # nosec comment
- Documented rather than disabling the rule globally

This reflects conscious risk acceptance and secure decision-making.

---

### Container Image Scanning (Trivy)
Docker images are scanned using Trivy during CI.

### Key points:
- Image is built during CI
- Trivy scans OS packages and application dependencies
- CI fails on HIGH or CRITICAL vulnerabilities

This prevents vulnerable container images from being merged into the main branch.

---

### Continuous Integration (CI)

### Pull Request Workflow

All changes are made via feature branches and merged through Pull Requests.

Each PR triggers a CI pipeline that runs:
- Terraform formatting and validation
- Checkov IaC security scanning
- Bandit SAST
- pip-audit dependency scanning
- Docker image build
- Trivy container image scanning

Branch protection ensures Pull Requests cannot be merged unless all checks pass.

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
- SBOM (Software Bill of Materials) generation
- Image promotion workflows
- Removal of SSH access using AWS SSM
- Application Load Balancer with HTTPS
- Manual approval gates for production deployments
- Migration to managed container services (ECS/EKS)

---

## Disclaimer
This project is for learning and demonstration purposes.  
Some configurations are intentionally simplified for clarity and cost control.

