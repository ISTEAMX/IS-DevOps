# Infrastructure Provisioning: IS-DevOps

## Overview
We use **Terraform** as our Infrastructure-as-Code (IaC) tool to provision and manage AWS resources in a repeatable and version-controlled manner.

## Terraform Workflow

### 1. Initialize
Before running any Terraform command, you must initialize the backend and download the necessary providers:
```bash
cd terraform/
terraform init
```
- **Remote State**: Terraform will connect to the `isteamx-devops-terraform-state-bucket` to fetch or create the state file.

### 2. Plan
Generate an execution plan to see exactly what Terraform will create, modify, or destroy:
```bash
terraform plan
```
- **Review**: Always review the plan to ensure no critical resources are being destroyed unexpectedly.

### 3. Apply
When you're ready to provision the resources, run:
```bash
terraform apply -auto-approve
```
- **Outputs**: Terraform will display several outputs (e.g., `frontend_website_endpoint`, `backend_public_ip`) which you'll need for the deployment phase.

### 4. Destroy (Optional)
To tear down the entire infrastructure and stop AWS charges (warning: this will delete all data in RDS and S3):
```bash
terraform destroy -auto-approve
```

## Modular Structure
The `terraform/` directory is organized into modules for better maintainability:
- `modules/s3/`: All frontend-related storage and hosting resources.
- `modules/ec2/`: Backend server, IAM roles, and Elastic IP.
- `modules/rds/`: PostgreSQL database instance and security groups.
- `modules/ecr/`: Docker image registry.
- `modules/secrets-manager/`: Configuration and runtime secret storage.
- `modules/cloudwatch/`: CloudWatch log groups, metric filters, alarms, and SNS alert topics.
