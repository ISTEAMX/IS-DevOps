# Setup & Prerequisites: IS-DevOps

## Overview
Before you can manage the cloud infrastructure, you need to configure your local development environment with the necessary CLI tools and AWS permissions.

## Prerequisites

### 1. CLI Tools
- **Terraform** (>= 1.0): [Download Terraform](https://developer.hashicorp.com/terraform/downloads).
- **AWS CLI** (v2): [Install AWS CLI](https://aws.amazon.com/cli/).
- **Docker Desktop**: [Download Docker](https://docs.docker.com/get-docker/).

### 2. AWS Configuration
Run the following command and provide your `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY`:
```bash
aws configure
```
- **Region**: `eu-central-1`
- **Output Format**: `json`

### 3. Manual Source Resources
The following resources must exist **manually** before running any Terraform automation:
- **S3 Bucket**: `isteamx-devops-terraform-state-bucket` — Used AS the remote backend.
- **Key Pair**: `isteamx-key` (`.pem`) — Used for SSH access to the EC2 server.
- **Elastic IP**: `35.158.14.254` — Reserved for the backend EC2 server.
- **Security Group**: `isteamx-backend-sg` — Referred to by the EC2 module.

## GitHub Registry Configuration
Ensure your GitHub repository has the following **Secrets** configured:
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `POSTGRES_DB` / `POSTGRES_USER` / `POSTGRES_PASSWORD`
- `JWT_SECRET_KEY` / `JWT_EXPIRATION`
- `EC2_SSH_KEY` (The content of your `isteamx-key-ec2.pem`)
