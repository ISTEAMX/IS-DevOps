# Cost Management: IS-DevOps

## Overview
The `IS-DevOps` project manages real AWS resources on the **AWS Free Tier**. We use custom automation to minimize costs and stay within free-tier limits.

## AWS Power Scheduler
We use a GitHub Actions workflow called **AWS Power Scheduler** (`.github/workflows/aws-power-scheduler.yml`) to pause and resume the environment daily.

### How to Use
1. Go to the **Actions** tab in the `IS-DevOps` GitHub repository.
2. Select **AWS Power Scheduler** from the left sidebar.
3. Click the **Run workflow** dropdown.
4. Choose an action:
   - **`start`**: Starts RDS first (needs ~5 min to become available), then starts EC2. Waits for EC2 to be in `running` state.
   - **`stop`**: Stops EC2 instances first, then stops RDS.

### What Happens on Start
1. **RDS starts first** — it takes ~5 minutes to become available, so starting it first gives it a head start.
2. **EC2 starts** — the workflow waits until the instance is in `running` state.
3. **Docker auto-restarts** — the backend container has `--restart unless-stopped`, so it starts automatically when Docker daemon boots. No manual redeploy needed.
4. **Flyway validates** — on startup, the backend checks migrations and says "No migration necessary."
5. **Elastic IP stays attached** — the public IP `35.158.14.254` persists across stop/start cycles.

### What Happens on Stop
1. EC2 instances stop — Docker container stops gracefully.
2. RDS instance stops — database enters `stopped` state (data is safe).
3. All data is preserved — RDS storage and EBS volumes retain data.

> **Note**: AWS automatically restarts a stopped RDS instance after 7 days. If you haven't started it manually before then, it will auto-start.

## Critical Warning: Elastic IPs
AWS Free Tier includes 750 hours/month of `t3.micro`. However:
- **Unused Elastic IP charge**: If the EC2 instance is **stopped**, AWS charges **~$3.60/month ($0.005/hr)** for the "idle" Elastic IP.
- **Recommendation**: If you must stop the server long-term, consider releasing the Elastic IP. For daily stop/start cycles (e.g., stop at night, start in the morning), the cost is minimal (~$0.06/night).

## Free Tier Considerations

| Resource | Free Tier Limit | Our Usage |
|----------|----------------|-----------|
| EC2 `t3.micro` | 750 hrs/month | ~350 hrs (daily stop/start) |
| RDS `db.t3.micro` | 750 hrs/month | ~350 hrs (daily stop/start) |
| RDS Storage | 20 GB gp3 | 20 GB (within limit) |
| RDS Backups | 20 GB | 1-day retention (minimal) |
| S3 | 5 GB + 20k GET | Well within limits |
| ECR | 500 MB | 5 images max (lifecycle policy) |
| CloudWatch | 10 metrics, 5 GB logs | Within limits |
| Elastic IP | Free when attached to running instance | ~$0.06/night when stopped |

## Usage Monitoring
- **Billing Dashboard**: Check the AWS Billing & Cost Management console regularly.
- **Budgets**: Set up an AWS Budget for $0.01 to receive email alerts.
- **CloudWatch Alarms**: CPU and health check alarms are configured via Terraform.
