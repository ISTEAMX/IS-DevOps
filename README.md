# IS-DevOps: Infrastructure & Deployment

This repository contains the infrastructure-as-code and Docker Compose configurations for the ISTEAMX project. You can choose between a **local development** setup or a **full AWS deployment**.

---

## Workflow 1: Local Development (Docker Compose)

This workflow is for developers who only need the core application running locally and do not need to interact with AWS.

### Prerequisites
- [Docker](https://docs.docker.com/get-docker/)

### Startup
```bash
# From the IS-DevOps/ root directory
docker-compose -f docker-compose/docker-compose.yml up --build -d
```

### Accessing the Application
| Service  | URL                                      |
|----------|------------------------------------------|
| Frontend | [http://localhost:80](http://localhost:80)     |
| Backend  | [http://localhost:8080](http://localhost:8080) |

### Shutdown
```bash
docker-compose -f docker-compose/docker-compose.yml down
```

> **Note:** Local development uses `.env` files for secrets — no AWS dependency. See `IS-Backend/.env.example` for the template.

---

## Workflow 2: AWS Deployment (Terraform)

This workflow provisions real AWS infrastructure and deploys the application to the cloud.

### Architecture Overview

| AWS Service | Purpose |
|-------------|---------|
| **S3** | Hosts the frontend as a static website |
| **EC2** (`t3.micro`, Ubuntu 22.04) | Runs the backend Docker container |
| **RDS** (`db.t3.micro`, PostgreSQL 15) | Managed PostgreSQL database with automated backups and encryption |
| **ECR** | Stores backend Docker images |
| **Secrets Manager** | Stores application runtime secrets (DB creds, JWT config, datasource URL) |
| **IAM** | Grants EC2 read-only access to ECR and Secrets Manager (least privilege) |
| **Elastic IP** | Provides a fixed public IP (`35.158.14.254`) for the backend |
| **S3 (state)** | Stores the Terraform state remotely (`isteamx-devops-terraform-state-bucket`) |

> **Region:** All resources are deployed to `eu-central-1`.

## Security Architecture

The AWS environment is built using least-privilege principles and zero-trust mechanisms:

1. **RDS Network Isolation**: The PostgreSQL database is completely hidden from the public internet. It resides in a private subnet group and its AWS Security Group strictly allows TCP traffic **only** from the backend EC2 instance.
2. **Secrets Manager**: Application runtime secrets (DB passwords, JWT keys, JDBC URLs) are never hardcoded in the repository or passed via plain CI/CD pipelines. They are stored securely in AWS Secrets Manager as a strictly IAM-protected JSON payload.
3. **IAM Least Privilege**: The backend EC2 server is assigned a minimal AWS IAM Instance Profile. It is only granted permission to pull Docker images from the exact ECR repository and read the exact application secret ARN. No long-lived credentials (`AWS_ACCESS_KEY_ID`) are stored on the EC2 server itself.
4. **Clean Repositories**: All `IS-DevOps`, `IS-Backend`, and `IS-Frontend` repositories have been audited. No real production credentials, SSH keys, or AWS access tokens are checked into version control.

### Secret Mapping Strategy

| Secret Location | What Goes There | Why |
|-----------------|-----------------|-----|
| **AWS Secrets Manager** | DB credentials, JWT config, JDBC URL | Runtime secrets — fetched dynamically by EC2 at deploy time/startup |
| **GitHub Repo Secrets** | AWS auth keys, SSH keys, ECR URL | CI/CD operational secrets — needed by GitHub runners strictly to push code |

### Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/downloads) (>= 1.0)
- [AWS CLI](https://aws.amazon.com/cli/) (v2)
- [Node.js](https://nodejs.org/) (for building the frontend)
- An AWS account with credentials configured (`aws configure`)

#### AWS Resources Created Outside Terraform
The following resources must exist **before** running `terraform apply`:
- **S3 bucket** `isteamx-devops-terraform-state-bucket` — used as the Terraform remote backend.
- **Security Group** `isteamx-backend-sg` — referenced by the EC2 module.
- **Key Pair** `isteamx-key` — used for SSH access to the EC2 instance.
- **Elastic IP** `35.158.14.254` — associated with the backend EC2 instance.

#### GitHub Repository Secrets

**IS-DevOps repo** (Terraform provisioning):

| Secret | Purpose |
|--------|---------|
| `AWS_ACCESS_KEY_ID` | Terraform AWS auth |
| `AWS_SECRET_ACCESS_KEY` | Terraform AWS auth |
| `POSTGRES_DB` | Seeds RDS + Secrets Manager |
| `POSTGRES_USER` | Seeds RDS + Secrets Manager |
| `POSTGRES_PASSWORD` | Seeds RDS + Secrets Manager |
| `JWT_SECRET_KEY` | Seeds Secrets Manager |
| `JWT_EXPIRATION` | Seeds Secrets Manager |

**IS-Backend repo** (CI/CD build & deploy):

| Secret | Purpose |
|--------|---------|
| `AWS_ACCESS_KEY_ID` | CI/CD AWS auth |
| `AWS_SECRET_ACCESS_KEY` | CI/CD AWS auth |
| `EC2_HOST` | SSH deploy target |
| `EC2_USER` | SSH username |
| `EC2_SSH_KEY` | SSH private key |
| `ECR_REPOSITORY_URL` | Docker image push target |
| `EC2_SECURITY_GROUP_ID` | Temp SSH rule management |
| `JWT_SECRET_KEY` | Maven build/tests |
| `JWT_EXPIRATION` | Maven build/tests |

**IS-Frontend repo** (CI/CD deploy):

| Secret | Purpose |
|--------|---------|
| `AWS_ACCESS_KEY_ID` | CI/CD AWS auth |
| `AWS_SECRET_ACCESS_KEY` | CI/CD AWS auth |

### Infrastructure Deployment

```bash
# From the IS-DevOps/terraform/ directory
terraform init
terraform apply -auto-approve
```

Terraform will output:
- `frontend_website_endpoint` — the S3 website URL for the frontend.
- `backend_public_ip` — the Elastic IP of the backend EC2 instance.
- `backend_repository_url` — the ECR repository URL for pushing backend images.
- `backend_security_group_id` — the ID of the backend security group.
- `rds_endpoint` — the RDS PostgreSQL connection endpoint.
- `rds_port` — the RDS instance port.
- `secret_arn` — the ARN of the Secrets Manager secret.

### Deploying the Frontend

Build the frontend locally and sync the output to the S3 bucket:

```bash
# From the project root
npm run build --prefix ../IS-Frontend

# Sync built files to S3
aws s3 sync ../IS-Frontend/dist s3://isteamx-unisync
```

The frontend will be available at the `frontend_website_endpoint` output by Terraform.

### Deploying the Backend

1. **Authenticate Docker with ECR:**
   ```bash
   aws ecr get-login-password --region eu-central-1 | docker login --username AWS --password-stdin <account-id>.dkr.ecr.eu-central-1.amazonaws.com
   ```

2. **Build & push the backend image:**
   ```bash
   docker build -t isteamx-backend ../IS-Backend
   docker tag isteamx-backend:latest <account-id>.dkr.ecr.eu-central-1.amazonaws.com/isteamx-backend:latest
   docker push <account-id>.dkr.ecr.eu-central-1.amazonaws.com/isteamx-backend:latest
   ```

3. **SSH into the EC2 instance and pull the image:**
   ```bash
   ssh -i isteamx-key.pem ubuntu@35.158.14.254

   # On the EC2 instance — fetch secrets from Secrets Manager
   SECRET_JSON=$(aws secretsmanager get-secret-value \
     --secret-id "isteamx/backend" \
     --region eu-central-1 \
     --query 'SecretString' \
     --output text)
   echo "$SECRET_JSON" | jq -r 'to_entries[] | "\(.key)=\(.value)"' > /home/ubuntu/app/.env

   # Pull and run the backend container
   aws ecr get-login-password --region eu-central-1 | docker login --username AWS --password-stdin <account-id>.dkr.ecr.eu-central-1.amazonaws.com
   docker pull <account-id>.dkr.ecr.eu-central-1.amazonaws.com/isteamx-backend:latest
   docker run -d --name backend --network isteamx-network -p 8080:8080 \
     --env-file /home/ubuntu/app/.env \
     <account-id>.dkr.ecr.eu-central-1.amazonaws.com/isteamx-backend:latest
   ```

> **Note:** Replace `<account-id>` with your AWS account ID. The EC2 instance has IAM permissions to read from Secrets Manager — no credentials needed.

### Accessing the Deployed Application

| Service  | URL |
|----------|-----|
| Frontend | S3 website endpoint (see `terraform output frontend_website_endpoint`) |
| Backend  | `http://35.158.14.254:8080` |

### Tearing Down Infrastructure

```bash
# From the IS-DevOps/terraform/ directory
terraform destroy -auto-approve
```

> **Warning:** This will destroy the EC2 instance, S3 bucket (including all objects), the ECR repository, the RDS PostgreSQL instance, and the Secrets Manager secret. The Terraform state bucket, Elastic IP, Security Group, and Key Pair are not managed by Terraform and will remain.

---

## AWS Power Scheduler (Cost Savings)

To ensure your AWS bill remains **$0.00** (using the AWS Free Tier) when you aren't developing, the repository includes a custom GitHub Actions workflow called **AWS Power Scheduler** (`.github/workflows/aws-power-scheduler.yml`).

### How to Start / Stop your Environment
1. Go to the **Actions** tab in this GitHub repository.
2. Select **AWS Power Scheduler** from the left sidebar.
3. Click the **Run workflow** dropdown on the right.
4. Choose an action:
   - **`stop`**: Shuts down the backend EC2 server and the RDS database. Computes are paused, saving free-tier hours. Storage data remains completely safe.
   - **`start`**: Boots up the backend EC2 server and the RDS database.

> **⚠️ Important Notice regarding Elastic IPs:** AWS allows you to run 1 `t3.micro` EC2 instance 24/7 for free under the 750-hours/month limit. However, if you **stop** the EC2 instance, AWS considers your Elastic IP as "unused" and will charge you **~$3.60/month ($0.005/hr)** until you turn the server back on or release the IP. If you want a strictly $0.00 bill without stopping, just leave the server running!

---

## Project Structure

```
IS-DevOps/
├── docker-compose/
│   └── docker-compose.yml              # Local development stack (backend + frontend + database)
├── terraform/
│   ├── backend.tf                       # Remote state configuration (S3)
│   ├── main.tf                          # Root module: provider, modules, outputs
│   └── modules/
│       ├── ec2/main.tf                  # EC2 instance, IAM role (ECR + Secrets Manager), Elastic IP
│       ├── ecr/main.tf                  # ECR repository for backend images
│       ├── rds/main.tf                  # RDS PostgreSQL instance, security group, subnet group
│       ├── s3/main.tf                   # S3 bucket with static website hosting
│       └── secrets-manager/main.tf      # AWS Secrets Manager secret for backend app config
└── README.md
```
