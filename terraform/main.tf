terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "eu-central-1"
}

# ─────────────────────────────────────────────────
# Variables
# ─────────────────────────────────────────────────

variable "postgres_db" {
  description = "PostgreSQL database name."
  type        = string
  sensitive   = true
}

variable "postgres_user" {
  description = "PostgreSQL username."
  type        = string
  sensitive   = true
}

variable "postgres_password" {
  description = "PostgreSQL password."
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

variable "alarm_emails" {
  description = "Email addresses for CloudWatch alarm notifications."
  type        = list(string)
  default = [
    "antonescu.andreiiosif@student.uoradea.ro",
    "czeli.zoltandragos@student.uoradea.ro",
    "laza.lukaspatrick@student.uoradea.ro"
  ]
}

# ─────────────────────────────────────────────────
# Modules
# ─────────────────────────────────────────────────

module "frontend_site" {
  source      = "./modules/s3"
  bucket_name = "isteamx-unisync"
}

module "backend_instance" {
  source        = "./modules/ec2"
  instance_name = "isteamx-backend"
  secret_arn    = module.backend_secrets.secret_arn
}

module "backend_repository" {
  source          = "./modules/ecr"
  repository_name = "isteamx-backend"
}

module "backend_database" {
  source                    = "./modules/rds"
  db_name                   = var.postgres_db
  db_username               = var.postgres_user
  db_password               = var.postgres_password
  backend_security_group_id = module.backend_instance.security_group_id
}

module "backend_secrets" {
  source         = "./modules/secrets-manager"
  db_name        = var.postgres_db
  db_username    = var.postgres_user
  db_password    = var.postgres_password
  jwt_secret_key = var.jwt_secret_key
  jwt_expiration = var.jwt_expiration
  rds_endpoint   = module.backend_database.rds_endpoint
}

module "monitoring" {
  source              = "./modules/cloudwatch"
  alarm_emails        = var.alarm_emails
  backend_instance_id = module.backend_instance.instance_id
}

# ─────────────────────────────────────────────────
# Outputs
# ─────────────────────────────────────────────────

output "frontend_website_endpoint" {
  description = "The S3 bucket website endpoint for the frontend."
  value       = module.frontend_site.website_endpoint
}

output "backend_public_ip" {
  description = "The public IP address of the backend EC2 instance."
  value       = module.backend_instance.public_ip
}

output "backend_repository_url" {
  description = "The URL of the backend ECR repository."
  value       = module.backend_repository.repository_url
}

output "backend_security_group_id" {
  description = "The ID of the backend security group."
  value       = module.backend_instance.security_group_id
}

output "rds_endpoint" {
  description = "The connection endpoint for the RDS PostgreSQL instance."
  value       = module.backend_database.rds_endpoint
}

output "rds_port" {
  description = "The port the RDS instance is listening on."
  value       = module.backend_database.rds_port
}

output "secret_arn" {
  description = "The ARN of the Secrets Manager secret."
  value       = module.backend_secrets.secret_arn
}
