# ─────────────────────────────────────────────────
# Variables
# ─────────────────────────────────────────────────

variable "db_name" {
  description = "Name of the PostgreSQL database to create."
  type        = string
  sensitive   = true
}

variable "db_username" {
  description = "Master username for the RDS instance."
  type        = string
  sensitive   = true
}

variable "db_password" {
  description = "Master password for the RDS instance."
  type        = string
  sensitive   = true
}

variable "backend_security_group_id" {
  description = "Security group ID of the backend EC2 instance (allowed to connect to RDS)."
  type        = string
}

variable "instance_class" {
  description = "RDS instance class."
  type        = string
  default     = "db.t3.micro"
}

variable "engine_version" {
  description = "PostgreSQL engine version."
  type        = string
  default     = "15"
}

variable "allocated_storage" {
  description = "Allocated storage in GB."
  type        = number
  default     = 20
}

variable "max_allocated_storage" {
  description = "Upper limit (GB) for RDS storage autoscaling. Set to 0 to disable."
  type        = number
  default     = 100
}

variable "monitoring_interval" {
  description = "Enhanced Monitoring interval in seconds (0 to disable, valid: 1,5,10,15,30,60)."
  type        = number
  default     = 60
}

# ─────────────────────────────────────────────────
# Data Sources
# ─────────────────────────────────────────────────

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# ─────────────────────────────────────────────────
# DB Subnet Group
# ─────────────────────────────────────────────────

resource "aws_db_subnet_group" "rds" {
  name       = "isteamx-rds-subnet-group"
  subnet_ids = data.aws_subnets.default.ids

  tags = {
    Name    = "isteamx-rds-subnet-group"
    Project = "isteamx"
  }
}

# ─────────────────────────────────────────────────
# Security Group — only the backend EC2 can connect
# ─────────────────────────────────────────────────

resource "aws_security_group" "rds" {
  name        = "isteamx-rds-sg"
  description = "Allow PostgreSQL access from the backend EC2 security group only."
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description     = "PostgreSQL from backend"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [var.backend_security_group_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "isteamx-rds-sg"
    Project = "isteamx"
  }
}

# ─────────────────────────────────────────────────
# IAM Role for Enhanced Monitoring
# ─────────────────────────────────────────────────

resource "aws_iam_role" "rds_enhanced_monitoring" {
  name = "isteamx-rds-enhanced-monitoring"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "monitoring.rds.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name    = "isteamx-rds-enhanced-monitoring"
    Project = "isteamx"
  }
}

resource "aws_iam_role_policy_attachment" "rds_enhanced_monitoring" {
  role       = aws_iam_role.rds_enhanced_monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

# ─────────────────────────────────────────────────
# RDS PostgreSQL Instance
# ─────────────────────────────────────────────────

resource "aws_db_instance" "postgres" {
  identifier     = "isteamx-postgres"
  engine         = "postgres"
  engine_version = var.engine_version
  instance_class = var.instance_class

  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage
  storage_type          = "gp3"
  storage_encrypted     = true

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  db_subnet_group_name   = aws_db_subnet_group.rds.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false
  multi_az               = true

  backup_retention_period = 1
  skip_final_snapshot     = true

  # Enhanced Monitoring
  monitoring_interval = var.monitoring_interval
  monitoring_role_arn = aws_iam_role.rds_enhanced_monitoring.arn

  # Performance Insights
  performance_insights_enabled = true

  tags = {
    Name    = "isteamx-postgres"
    Project = "isteamx"
  }
}

# ─────────────────────────────────────────────────
# Outputs
# ─────────────────────────────────────────────────

output "rds_endpoint" {
  description = "The connection endpoint for the RDS instance (host:port)."
  value       = aws_db_instance.postgres.endpoint
}

output "rds_hostname" {
  description = "The hostname of the RDS instance (without port)."
  value       = aws_db_instance.postgres.address
}

output "rds_port" {
  description = "The port the RDS instance is listening on."
  value       = aws_db_instance.postgres.port
}

output "rds_security_group_id" {
  description = "The security group ID of the RDS instance."
  value       = aws_security_group.rds.id
}
