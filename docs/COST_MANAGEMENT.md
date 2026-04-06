# Cost Management: IS-DevOps

## Overview
As the `IS-DevOps` project manages real AWS resources, it's critical to monitor and control infrastructure costs. We leverage the **AWS Free Tier** and custom automation to maintain a **$0.00** monthly bill.

## AWS Power Scheduler
We've implemented a custom GitHub Actions workflow called **AWS Power Scheduler** (`.github/workflows/aws-power-scheduler.yml`) to pause and resume the environment.

### How to Use
1.  Go to the **Actions** tab in this GitHub repository.
2.  Select **AWS Power Scheduler** from the left sidebar.
3.  Click the **Run workflow** dropdown on the right.
4.  Choose an action:
    - **`stop`**: Shuts down the backend EC2 server and the RDS database. Computes are paused, saving free-tier hours. Storage data remains completely safe.
    - **`start`**: Boots up the backend EC2 server and the RDS database.

## Critical Warning: Elastic IPs
AWS allows you to run 1 `t3.micro` EC2 instance 24/7 for free under the 750-hours/month limit. However:
- **Unused Elastic IP charge**: If you **stop** the EC2 instance, AWS considers your Elastic IP as "unused" and will charge you **~$3.60/month ($0.005/hr)** until you turn the server back on or release the IP.
- **Recommendation**: If you want a strictly $0.00 bill without stopping, just leave the server running! If you MUST stop the server, consider releasing the Elastic IP if you're not planning to start it soon.

## Usage Monitoring
- **Billing Dashboard**: Check the AWS Billing & Cost Management console regularly.
- **Budgets**: Set up an AWS Budget for $0.01 to receive an email alert if any charges are incurred.
- **CloudWatch Alarms**: Set up alarms for instance CPU usage to ensure no unexpected processes are running.
