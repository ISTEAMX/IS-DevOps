# Deployment Guide: IS-DevOps

## Overview
Once the infrastructure is provisioned with Terraform, application deployments are fully automated via **GitHub Actions** workflows. Manual deployments are also documented below for reference.

## 1. Frontend Deployment (S3)

### Automated (Recommended)
Trigger the **Manual Deploy Frontend** workflow from the `IS-Frontend` repo → Actions → `deploy.yml` → Run workflow.

The workflow automatically:
1. Checks out the code, installs dependencies, lints, and builds with the production API URL
2. Syncs the `dist/` folder to the `isteamx-unisync` S3 bucket

### Manual
```bash
# From the IS-Frontend/ root directory
npm ci
VITE_API_URL=http://35.158.14.254:8080 npm run build
aws s3 sync dist/ s3://isteamx-unisync --delete
```

**Access**: The frontend is available at `http://isteamx-unisync.s3-website.eu-central-1.amazonaws.com`

## 2. Backend Deployment (ECR & EC2)

### Automated (Recommended)
Trigger the **Manual Deploy Backend** workflow from the `IS-Backend` repo → Actions → `deploy.yml` → Run workflow.

The workflow automatically:
1. Temporarily opens SSH (port 22) for the GitHub runner's IP only
2. Builds the Docker image and pushes to ECR (tagged with commit SHA)
3. SSHs into EC2 and:
   - Pulls the latest image from ECR
   - Fetches secrets from AWS Secrets Manager → writes `.env` (chmod 600)
   - Stops old container, starts new one with `--restart unless-stopped`
4. Revokes the temporary SSH rule

### Manual
```bash
# A. ECR Authentication
aws ecr get-login-password --region eu-central-1 | docker login --username AWS --password-stdin <account-id>.dkr.ecr.eu-central-1.amazonaws.com

# B. Build & Push Image (from IS-Backend/)
docker build -t isteamx-backend .
docker tag isteamx-backend:latest <account-id>.dkr.ecr.eu-central-1.amazonaws.com/isteamx-backend:latest
docker push <account-id>.dkr.ecr.eu-central-1.amazonaws.com/isteamx-backend:latest

# C. Deploy to EC2
ssh -i isteamx-key-ec2.pem ubuntu@35.158.14.254

# On the EC2 instance:
aws ecr get-login-password --region eu-central-1 | docker login --username AWS --password-stdin <account-id>.dkr.ecr.eu-central-1.amazonaws.com
docker pull <account-id>.dkr.ecr.eu-central-1.amazonaws.com/isteamx-backend:latest

# Fetch secrets
SECRET_JSON=$(aws secretsmanager get-secret-value --secret-id "isteamx/backend" --region eu-central-1 --query 'SecretString' --output text)
echo "$SECRET_JSON" | jq -r 'to_entries[] | "\(.key)=\(.value)"' > /home/ubuntu/app/.env
chmod 600 /home/ubuntu/app/.env

# Stop old, start new
docker stop isteamx-backend || true
docker rm isteamx-backend || true
docker run -d \
  --name isteamx-backend \
  --restart unless-stopped \
  -p 8080:8080 \
  --network isteamx-network \
  --env-file /home/ubuntu/app/.env \
  <account-id>.dkr.ecr.eu-central-1.amazonaws.com/isteamx-backend:latest
```

> **Important**: Always use `--restart unless-stopped` so the container auto-starts after EC2 reboots (e.g., after the daily stop/start cycle).

## 3. CI/CD Workflows (GitHub Actions)

All reusable workflows live in `IS-DevOps/.github/workflows/`:

| Workflow | Trigger | Description |
|----------|---------|-------------|
| `continuous-build-backend.yml` | Called by IS-Backend on push/PR | Runs tests, builds JAR, validates Dockerfile |
| `continuous-build-frontend.yml` | Called by IS-Frontend on push/PR | Lints, tests, builds, uploads artifact, validates Dockerfile |
| `continuous-release-backend.yml` | Called by IS-Backend on push to main | Semantic versioning, git tag, GitHub Release |
| `continuous-release-frontend.yml` | Called by IS-Frontend on push to main | Semantic versioning, git tag, GitHub Release |
| `continuous-deployment-backend.yml` | Called by IS-Backend manual deploy | Build → Push ECR → SSH deploy to EC2 |
| `continuous-deployment-frontend.yml` | Called by IS-Frontend manual deploy | Build → S3 sync |
| `aws-power-scheduler.yml` | Manual dispatch | Start or stop EC2 + RDS to save costs |
| `terraform.yml` | On push to IS-DevOps main | Terraform plan and apply |

## 4. Database Migrations on Deploy
When the backend container starts, **Flyway** automatically:
1. Connects to RDS PostgreSQL
2. Checks `flyway_schema_history` table
3. Runs any **new** migration files (e.g., `V7__*.sql`)
4. Existing data (professors, schedules added via the app) is **never touched**

> **Never edit** an already-applied migration file. Always create a new versioned file.
