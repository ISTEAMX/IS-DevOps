# Project Overview: IS-DevOps

## Infrastructure & Deployment Strategy
The `IS-DevOps` repository is the central hub for the **ISTEAMX** project's infrastructure-as-code (IaC) and container orchestration. It provides two distinct workflows to support both rapid local development and scalable cloud deployment.

## Key Workflows

### 1. Local Development (Docker Compose)
- **Goal**: Provide a quick, environment-agnostic way for developers to run the entire backend and frontend stack locally.
- **Tools**: Docker, Docker Compose.
- **Outcome**: A fully functional local environment with hot-reloading (frontend) and a local PostgreSQL instance.

### 2. Cloud Infrastructure (Terraform & AWS)
- **Goal**: Provision and manage production-grade infrastructure on AWS.
- **Tools**: Terraform, AWS CLI.
- **Outcome**: A secure, multi-resource cloud environment including S3 (frontend), EC2 (backend), RDS (database), ECR (image registry), and Secrets Manager (sensitive config).

## Repository Scope
- **Containerization**: Docker Compose files for multi-container orchestration.
- **Infrastructure Provisioning**: Terraform modules for modular AWS resource management.
- **Monitoring & Alerting**: AWS CloudWatch integration for error tracking, metrics, and health alarms with email notifications.
- **Automation**: CI/CD workflows (GitHub Actions) for provisioning, deployment, and cost management (Power Scheduler).
