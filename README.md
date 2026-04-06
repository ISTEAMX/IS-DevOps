# IS-DevOps 🚀

[![Terraform](https://img.shields.io/badge/Terraform-1.0+-purple.svg)](https://www.terraform.io/)
[![Docker](https://img.shields.io/badge/Docker-Enabled-blue.svg)](https://www.docker.com/)
[![AWS](https://img.shields.io/badge/AWS-Infrastructure-orange.svg)](https://aws.amazon.com/)

Infrastructure-as-Code and deployment configurations for the **ISTEAMX** University Management System. This repository manages both the local development environment and the core AWS cloud infrastructure.

---

## 🚀 Quick Start

### 🏠 Local Development (Docker Compose)
Run the entire application stack locally without any AWS dependencies:
```bash
# From the root directory
docker-compose -f docker-compose/docker-compose.yml up --build -d
```
Access the application at [http://localhost:80](http://localhost:80).

### ☁️ AWS Infrastructure (Terraform)
Provision the production environment on AWS:
```bash
cd terraform/
terraform init
terraform apply -auto-approve
```

---

## ✨ Key Capabilities
- **Modular Infrastructure**: Terraform-managed S3, EC2, RDS, ECR, and Secrets Manager.
- **Security-First Design**: Zero-trust IAM roles, isolated database subnets, and centralized secret management.
- **Local Simulation**: Docker Compose environment mirroring the production stack for rapid testing.
- **Cost Automation**: Custom GitHub Actions (Power Scheduler) to maintain a $0.00 AWS bill.

---

## 🛠️ Technologies Used
- **IaC**: Terraform (Modular approach)
- **Containerization**: Docker, Docker Compose
- **Cloud Provider**: AWS (EC2, S3, RDS, ECR, Secrets Manager)
- **CI/CD**: GitHub Actions
- **Security**: IAM Instance Profiles, Security Groups, Secrets Manager

---

## 📚 Project Documentation
For detailed information on the project's architecture, setup, and deployment procedures, please refer to the files in the [docs/](docs/) folder:

- [**Project Overview**](docs/PROJECT_OVERVIEW.md): Local vs. Cloud development workflows.
- [**Local Development**](docs/LOCAL_DEVELOPMENT.md): Detailed guide for the Docker Compose stack.
- [**AWS Architecture**](docs/AWS_ARCHITECTURE.md): Technical breakdown of cloud resources and mapping.
- [**Security Architecture**](docs/SECURITY_ARCHITECTURE.md): Deep-dive into IAM, Secrets Manager, and Networking.
- [**Setup & Prerequisites**](docs/SETUP_AND_PREREQUISITES.md): CLI tools and initial AWS configuration.
- [**Infrastructure Provisioning**](docs/INFRASTRUCTURE_PROVISIONING.md): Detailed Terraform lifecycle guide.
- [**Deployment Guide**](docs/DEPLOYMENT_GUIDE.md): Pushing Frontend/S3 and Backend/ECR/EC2.
- [**Cost Management**](docs/COST_MANAGEMENT.md): Using the Power Scheduler and Elastic IP warnings.
- [**Troubleshooting**](docs/TROUBLESHOOTING.md): Common connectivity and provisioning issues.

---

## 🤝 Contributing
We welcome contributions! Please refer to the [Infrastructure Provisioning](docs/INFRASTRUCTURE_PROVISIONING.md) guide for Terraform standards and module structures.

---

## 📄 License
This project is licensed under the [MIT License](LICENSE) (or as per project policy).

