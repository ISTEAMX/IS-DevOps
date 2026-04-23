# Monitoring & Alerting: IS-DevOps

## Overview
The ISTEAMX platform uses **AWS CloudWatch** (free tier) for centralized error tracking, application metrics, and health monitoring. Alerts are delivered via **AWS SNS** email notifications.

## Architecture

### Error Flow
```
Frontend (Browser)
  ├── window.onerror / unhandledrejection
  ├── React ErrorBoundary
  └── Axios error interceptor
        │
        ▼
Backend: POST /api/monitoring/error
        │
        ▼
CloudWatchErrorReporter
        │
        ▼
AWS CloudWatch Logs (/isteamx/backend)
        │
        ▼
CloudWatch Metric Filter (error count)
        │
        ▼
CloudWatch Alarms → SNS → Email Notifications
```

### Metrics Flow
```
Spring Boot Actuator + Micrometer
        │
        ▼
AWS CloudWatch Metrics (namespace: isteamx-backend)
  ├── JVM metrics (memory, threads, GC)
  ├── HTTP request metrics (count, latency)
  └── Database connection pool metrics
```

## Alert Recipients
The following team members receive alarm notifications via email:
- `antonescu.andreiiosif@student.uoradea.ro`
- `czeli.zoltandragos@student.uoradea.ro`
- `laza.lukaspatrick@student.uoradea.ro`

> **Important**: After running `terraform apply`, each recipient must **confirm the SNS subscription** by clicking the link in the confirmation email from AWS.

## CloudWatch Alarms

| Alarm | Condition | Description |
|-------|-----------|-------------|
| `isteamx-high-error-rate` | >10 errors in 5 minutes | Fires when the backend logs more than 10 `ERROR`-level events within a 5-minute window. |
| `isteamx-ec2-health` | Health check fails for 2 consecutive periods | Fires when the EC2 instance fails AWS status checks. |
| `isteamx-high-cpu` | CPU >80% for 15 minutes | Fires when average CPU utilization exceeds 80% over three 5-minute periods. |

## AWS Resources (Terraform Module: `cloudwatch/`)

| Resource | Name | Purpose |
|----------|------|---------|
| Log Group | `/isteamx/backend` | Stores structured error events (14-day retention). |
| Log Stream | `app` | Single stream within the log group for application errors. |
| Metric Filter | `isteamx-backend-errors` | Counts log entries containing `"level":"ERROR"`. |
| SNS Topic | `isteamx-alerts` | Fan-out topic for alarm notifications. |
| SNS Subscriptions | 3x email | One per team member. |
| CloudWatch Alarms | 3x alarms | Error rate, EC2 health, CPU utilization. |

## Configuration

### Environment Variables
| Variable | Default | Description |
|----------|---------|-------------|
| `CLOUDWATCH_ENABLED` | `false` (local) / `true` (docker-compose) | Enables/disables CloudWatch log shipping. |
| `AWS_REGION` | `eu-central-1` | AWS region for CloudWatch API calls. |
| `CLOUDWATCH_LOG_GROUP` | `/isteamx/backend` | CloudWatch Log Group name. |
| `CLOUDWATCH_LOG_STREAM` | `app` | CloudWatch Log Stream name. |

### Local Development
CloudWatch is **disabled by default** for local development. Errors are still logged to the console via SLF4J. To test CloudWatch locally:
```bash
export CLOUDWATCH_ENABLED=true
export AWS_ACCESS_KEY_ID=<your-key>
export AWS_SECRET_ACCESS_KEY=<your-secret>
```

### Production (EC2)
CloudWatch is **enabled by default** in the Docker Compose configuration. The EC2 instance uses its IAM Instance Profile for authentication — no AWS keys needed.

## Viewing Logs & Metrics

### CloudWatch Logs
1. Go to **AWS Console → CloudWatch → Log Groups → `/isteamx/backend`**.
2. Click on the `app` log stream.
3. Each entry is a structured JSON object with fields: `level`, `context`, `exception`, `message`, `stackTrace`, `timestamp`.

### CloudWatch Metrics
1. Go to **AWS Console → CloudWatch → Metrics → Custom Namespaces → `isteamx-backend`**.
2. Browse JVM, HTTP, and database metrics.

### Actuator Endpoints
- **Health**: `GET /actuator/health` (public)
- **Info**: `GET /actuator/info` (public)
- **Metrics**: `GET /actuator/metrics` (authenticated)
- **Loggers**: `GET /actuator/loggers` (authenticated)

## Free Tier Limits
All monitoring resources fit within the AWS Free Tier:
- **CloudWatch Logs**: 5 GB ingestion + 5 GB storage per month.
- **CloudWatch Alarms**: 10 alarms (we use 3).
- **CloudWatch Metrics**: 10 custom metrics + 1M API requests per month.
- **SNS**: 1M publishes per month.

