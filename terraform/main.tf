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

module "frontend_site" {
  source      = "./modules/s3"
  bucket_name = "isteamx-unisync"
}

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

module "backend_instance" {
  source            = "./modules/ec2"
  instance_name     = "isteamx-backend"
  postgres_db       = var.postgres_db
  postgres_user     = var.postgres_user
  postgres_password = var.postgres_password
}

module "backend_repository" {
  source          = "./modules/ecr"
  repository_name = "isteamx-backend"
}

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
