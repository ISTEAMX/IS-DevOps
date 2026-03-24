terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  backend "s3" {
    bucket = "isteamx-devops-terraform-state-bucket"
    key    = "terraform.tfstate"
    region = "eu-central-1"
  }
}

provider "aws" {
  region = "eu-central-1"
}

module "frontend_site" {
  source      = "./modules/s3"
  bucket_name = "isteamx-frontend-bucket-for-devops"
}

module "backend_instance" {
  source        = "./modules/ec2"
  instance_name = "isteamx-backend"
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
