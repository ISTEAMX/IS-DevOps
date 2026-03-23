terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# By removing the provider "docker" block, Terraform will automatically
# use the default Docker socket for the user's operating system.
# For Colima/Docker Desktop users on Mac, this works out of the box.

provider "aws" {
  region                      = "us-east-1"
  access_key                  = "test"
  secret_key                  = "test"
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true

  endpoints {
    s3 = "http://127.0.0.1:4566"
  }
}

resource "docker_network" "isteamx" {
  name = "isteamx-network"
}

module "localstack" {
  source   = "./modules/localstack"
  networks = [docker_network.isteamx.name]
}

module "frontend_site" {
  source      = "./modules/s3-static-site"
  bucket_name = "isteamx-frontend"
  depends_on = [
    module.localstack
  ]
}

output "localstack_container_name" {
  description = "Name of the LocalStack container"
  value       = module.localstack.container_name
}

output "localstack_container_id" {
  description = "ID of the LocalStack container"
  value       = module.localstack.container_id
}

output "frontend_website_endpoint" {
  description = "The S3 bucket website endpoint for the frontend."
  value       = module.frontend_site.website_endpoint
}
