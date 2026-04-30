# Security Architecture: IS-DevOps

## Overview
The `IS-DevOps` environment is built using **least-privilege** principles and **zero-trust** mechanisms to ensure the project remains secure and compliant with modern cloud security standards.

## Security Controls

### 1. Secrets Management (AWS Secrets Manager)
To prevent hardcoded secrets in the repository, we use **AWS Secrets Manager**:
- **Application Secrets**: JWT keys, database passwords, and JDBC URLs are stored as a JSON payload in a single secret (`isteamx/backend`).
- **Dynamic Retrieval**: The backend EC2 instance fetches these secrets at deploy time via the AWS CLI.
- **Access Control**: IAM policies strictly limit who can read or write to this specific secret ARN.

### 2. IAM Least Privilege (Instance Profile)
The backend EC2 server is assigned a minimal **AWS IAM Instance Profile**:
- **ECR Pull Access**: Only granted permission to pull Docker images from the `isteamx-backend` repository.
- **Secrets Manager Read Access**: Only granted permission to read the `isteamx/backend` secret.
- **CloudWatch Write Access**: Granted permission to create log groups/streams, put log events, and publish custom metrics (scoped to `/isteamx/*` log groups and `isteamx-backend` namespace).
- **Zero-Credential Strategy**: No long-lived AWS keys (`AWS_ACCESS_KEY_ID`) are stored on the EC2 server itself.

### 3. Network Isolation (Security Groups)
- **RDS Isolation**: The database instance is located in a private Subnet Group, making it inaccessible from the public internet. Its Security Group is configured to **only** allow inbound traffic on port `5432` from the Backend EC2 Security Group.
- **EC2 Security Group**: Only allows inbound traffic on port `8080` (API). SSH (port 22) is temporarily opened during CI/CD deployments for the GitHub runner's IP only, then immediately revoked.

### 4. Docker Container Security
- **Restart Policy**: Containers run with `--restart unless-stopped` to survive EC2 reboots.
- **Environment File**: The `.env` file containing secrets has `chmod 600` (owner-only read/write).
- **ECR Tag Mutability**: Set to `MUTABLE` to allow CI/CD re-deploys of the same commit SHA. Each deploy uses a unique commit SHA tag.

### 5. Secrets Breakdown
| Secret | Location | Purpose |
|--------|---------|---------|
| **AWS Secrets Manager** | `isteamx/backend` | App runtime secrets (JDBC URL, JWT keys, DB credentials). |
| **GitHub Repo Secrets** | GitHub Repository | CI/CD operational secrets (AWS keys, SSH keys, ECR URL, SG ID). |

## Security Best Practices
- **No Private Keys in Git**: SSH keys (`.pem`) and AWS credentials are never committed.
- **Encrypted Database**: The RDS instance uses AWS KMS for at-rest encryption (`storage_encrypted = true`).
- **Encrypted State**: Terraform state is stored in S3 with encryption enabled.
- **Temporary SSH Access**: CI/CD deployments open port 22 only for the runner's IP, then revoke it in an `if: always()` step.
- **Stateless JWT Auth**: The backend uses stateless JWT authentication — no session cookies, no CSRF risk.
