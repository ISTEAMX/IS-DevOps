# Deployment Guide: IS-DevOps

## Overview
Once the infrastructure is provisioned with Terraform, you must build and deploy the application code to the corresponding AWS services.

## 1. Frontend Deployment (S3)
The frontend is built as a static application and synced to an S3 bucket configured for website hosting.

```bash
# From the IS-Frontend/ root directory
npm install
npm run build

# Sync built assets to S3
aws s3 sync dist s3://isteamx-unisync
```
- **Access**: The frontend will be available at the `frontend_website_endpoint` output by Terraform.

## 2. Backend Deployment (ECR & EC2)
The backend is built as a Docker image, pushed to ECR, and then pulled/run on the EC2 instance.

### A. ECR Authentication
```bash
aws ecr get-login-password --region eu-central-1 | docker login --username AWS --password-stdin <account-id>.dkr.ecr.eu-central-1.amazonaws.com
```

### B. Build & Push Image
```bash
# From the IS-Backend/ root directory
docker build -t isteamx-backend .
docker tag isteamx-backend:latest <account-id>.dkr.ecr.eu-central-1.amazonaws.com/isteamx-backend:latest
docker push <account-id>.dkr.ecr.eu-central-1.amazonaws.com/isteamx-backend:latest
```

### C. Deploy to EC2 (SSH)
1.  **SSH into EC2**: `ssh -i isteamx-key.pem ubuntu@35.158.14.254`
2.  **Fetch Secrets**: `aws secretsmanager get-secret-value --secret-id "isteamx/backend" --region eu-central-1 --query 'SecretString' --output text > .env`
3.  **Pull & Run**:
    ```bash
    aws ecr get-login-password --region eu-central-1 | docker login --username AWS --password-stdin <account-id>.dkr.ecr.eu-central-1.amazonaws.com
    docker pull <account-id>.dkr.ecr.eu-central-1.amazonaws.com/isteamx-backend:latest
    docker run -d --name backend -p 8080:8080 --env-file .env <account-id>.dkr.ecr.eu-central-1.amazonaws.com/isteamx-backend:latest
    ```

## 3. CI/CD Workflows (GitHub Actions)
The project includes automated workflows in `.github/workflows/` for:
- **Build & Push**: Automatically triggers on PR merge to `main`.
- **Infrastructure Provisioning**: Terraform plan and apply on commit.
