# Security Architecture: IS-DevOps

## Overview
The `IS-DevOps` environment is built using **least-privilege** principles and **zero-trust** mechanisms to ensure the project remains secure and compliant with modern cloud security standards.

## Security Controls

### 1. Secrets Management (AWS Secrets Manager)
To prevent hardcoded secrets in the repository, we use **AWS Secrets Manager**:
- **Application Secrets**: JWT keys, database passwords, and JDBC URLs are stored as a JSON payload in a single secret (`isteamx/backend`).
- **Dynamic Retrieval**: The backend EC2 instance fetches these secrets at runtime via the AWS CLI.
- **Access Control**: IAM policies strictly limit who can read or write to this specific secret ARN.

### 2. IAM Least Privilege (Instance Profile)
The backend EC2 server is assigned a minimal **AWS IAM Instance Profile**:
- **ECR Pull Access**: Only granted permission to pull Docker images from the `isteamx-backend` repository.
- **Secrets Manager Read Access**: Only granted permission to read the `isteamx/backend` secret.
- **Zero-Credential Strategy**: No long-lived AWS keys (`AWS_ACCESS_KEY_ID`) are stored on the EC2 server itself.

### 3. Network Isolation (Security Groups)
- **RDS Isolation**: The database instance is located in a private subnet group. Its Security Group is configured to **only** allow inbound traffic on port `5432` from the Backend EC2 Security Group.
- **EC2 Security Group**: Only allows inbound traffic on ports `8080` (API) and `22` (SSH - restricted to developer IP).

### 4. Secrets Breakdown
| Secret | Location | Purpose |
|--------|---------|---------|
| **AWS Secrets Manager** | `isteamx/backend` | App runtime secrets (JDBC, JWT keys). |
| **GitHub Repo Secrets** | GitHub Repository | CI/CD operational secrets (AWS keys, SSH keys, ECR URL). |

## Security Best Practices
- **No Private Keys in Git**: SSH keys (`.pem`) and AWS credentials are never committed.
- **Encrypted Database**: The RDS instance uses AWS KMS for at-rest encryption.
- **Regular Audits**: We periodically check repositories for any accidental secret exposure.
