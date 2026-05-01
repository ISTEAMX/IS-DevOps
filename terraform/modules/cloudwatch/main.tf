variable "log_group_name" {
  description = "CloudWatch log group name"
  type        = string
  default     = "/isteamx/backend"
}

variable "retention_days" {
  description = "Log retention in days"
  type        = number
  default     = 14
}

variable "alarm_emails" {
  description = "Email addresses for CloudWatch alarm notifications"
  type        = list(string)
}

variable "asg_name" {
  description = "Auto Scaling Group name for health monitoring"
  type        = string
}

resource "aws_cloudwatch_log_group" "backend" {
  name              = var.log_group_name
  retention_in_days = var.retention_days

  tags = {
    Project = "isteamx"
  }
}

resource "aws_cloudwatch_log_stream" "app" {
  name           = "app"
  log_group_name = aws_cloudwatch_log_group.backend.name
}

resource "aws_sns_topic" "alerts" {
  name = "isteamx-alerts"
}

resource "aws_sns_topic_subscription" "emails" {
  for_each  = toset(var.alarm_emails)
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = each.value
}

resource "aws_cloudwatch_log_metric_filter" "errors" {
  name           = "isteamx-backend-errors"
  log_group_name = aws_cloudwatch_log_group.backend.name
  pattern        = "{ $.level = \"ERROR\" }"

  metric_transformation {
    name      = "BackendErrorCount"
    namespace = "isteamx-backend"
    value     = "1"
  }
}

resource "aws_cloudwatch_metric_alarm" "high_error_rate" {
  alarm_name          = "isteamx-high-error-rate"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "BackendErrorCount"
  namespace           = "isteamx-backend"
  period              = 300
  statistic           = "Sum"
  threshold           = 10
  alarm_description   = "More than 10 errors in 5 minutes"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "notBreaching"
}

resource "aws_cloudwatch_metric_alarm" "asg_unhealthy" {
  alarm_name          = "isteamx-asg-unhealthy"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "GroupInServiceInstances"
  namespace           = "AWS/AutoScaling"
  period              = 300
  statistic           = "Minimum"
  threshold           = 1
  alarm_description   = "No healthy instances in the ASG — self-healing should kick in"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "breaching"

  dimensions = {
    AutoScalingGroupName = var.asg_name
  }
}

resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  alarm_name          = "isteamx-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "CPU above 80% for 15 minutes"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    AutoScalingGroupName = var.asg_name
  }
}

output "log_group_name" {
  value = aws_cloudwatch_log_group.backend.name
}

output "sns_topic_arn" {
  value = aws_sns_topic.alerts.arn
}
