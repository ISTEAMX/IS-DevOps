# ─────────────────────────────────────────────────
# Variables
# ─────────────────────────────────────────────────

variable "db_name" {
  description = "PostgreSQL database name."
  type        = string
  sensitive   = true
}

variable "db_username" {
  description = "PostgreSQL master username."
  type        = string
  sensitive   = true
}

variable "db_password" {
  description = "PostgreSQL master password."
  type        = string
  sensitive   = true
}

variable "jwt_secret_key" {
  description = "JWT signing secret key."
  type        = string
  sensitive   = true
}

variable "jwt_expiration" {
  description = "JWT token expiration time in milliseconds."
  type        = string
  sensitive   = true
}

variable "rds_endpoint" {
  description = "The RDS PostgreSQL endpoint (host:port) used to compose the JDBC URL."
  type        = string
}

variable "secret_name" {
  description = "Name of the Secrets Manager secret."
  type        = string
  default     = "isteamx/backend"
}

# ─────────────────────────────────────────────────
# Secrets Manager Secret
# ─────────────────────────────────────────────────

resource "aws_secretsmanager_secret" "backend" {
  name                    = var.secret_name
  description             = "Application secrets for the ISTEAMX backend service."
  recovery_window_in_days = 7

  tags = {
    Name    = var.secret_name
    Project = "isteamx"
  }
}

resource "aws_secretsmanager_secret_version" "backend" {
  secret_id = aws_secretsmanager_secret.backend.id

  secret_string = jsonencode({
    POSTGRES_DB            = var.db_name
    POSTGRES_USER          = var.db_username
    POSTGRES_PASSWORD      = var.db_password
    SPRING_DATASOURCE_URL  = "jdbc:postgresql://${var.rds_endpoint}/${var.db_name}"
    JWT_SECRET_KEY         = var.jwt_secret_key
    JWT_EXPIRATION         = var.jwt_expiration
  })
}

# ─────────────────────────────────────────────────
# Outputs
# ─────────────────────────────────────────────────

output "secret_arn" {
  description = "ARN of the Secrets Manager secret."
  value       = aws_secretsmanager_secret.backend.arn
}

output "secret_name" {
  description = "Name of the Secrets Manager secret."
  value       = aws_secretsmanager_secret.backend.name
}
