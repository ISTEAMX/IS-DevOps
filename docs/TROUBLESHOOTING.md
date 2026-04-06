# Troubleshooting & Debugging: IS-DevOps

## Common Issues & Solutions

### 1. Terraform State Lock
- **Error**: `Error acquiring the state lock`.
- **Solution**: Terraform prevents simultaneous modifications to avoid state corruption. If you're sure no one else is running Terraform, delete the `.terraform.tfstate.lock.info` file from the `isteamx-devops-terraform-state-bucket` in S3.

### 2. RDS Connection Failure from Backend
- **Error**: Backend cannot connect to the database.
- **Solution**: Check the RDS Security Group's inbound rules. It should explicitly allow traffic on port `5432` from the Backend EC2 Security Group.

### 3. SSH Connectivity Issues
- **Error**: `Permission denied (publickey)` when trying to SSH into the EC2 server.
- **Solution**: Ensure your `isteamx-key-ec2.pem` has the correct permissions (`chmod 400 isteamx-key-ec2.pem`) and that the `EC2 Security Group` allows port `22` (SSH) from your current public IP.

### 4. Docker Build Failures on EC2
- **Error**: `insufficient space` or `command not found`.
- **Solution**: Check the EC2 instance's disk usage (`df -h`). If out of space, run `docker system prune -a` to clear old images and containers.

### 5. Secrets Manager Fetch Error
- **Error**: `AccessDeniedException` when fetching secrets on EC2.
- **Solution**: Verify the IAM Instance Profile assigned to the EC2 instance. It must have a policy allowing `secretsmanager:GetSecretValue` for the specific secret ARN.

## Debugging Techniques

### Terraform Logs
Enable detailed Terraform logging if an infrastructure script is failing:
```bash
export TF_LOG=DEBUG
terraform apply
```

### AWS CloudWatch Logs
Check the **CloudWatch** console for:
- **RDS Logs**: Identifying database startup or connection errors.
- **EC2 Logs**: View system logs to identify startup script failures.

### Local Simulation
Always test your `docker-compose.yml` locally before deploying to AWS. If it doesn't work locally, it likely won't work in the cloud.
