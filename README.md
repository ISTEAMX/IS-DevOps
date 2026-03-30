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

### Secret Management Strategy

Application runtime secrets are stored in **AWS Secrets Manager** as a single JSON secret (`isteamx/backend`). The EC2 instance fetches them dynamically at startup and during deployments using its IAM role — no secrets are hardcoded in config files or passed through CI/CD environment variables.

| Secret Location | What Goes There | Why |
|-----------------|-----------------|-----|
| **AWS Secrets Manager** | DB credentials, JWT config, JDBC URL | Runtime secrets — fetched by EC2 at deploy time |
| **GitHub Repo Secrets** | AWS keys, SSH keys, ECR URL, SG ID | CI/CD operational secrets — needed by GitHub runners |

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
