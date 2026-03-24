variable "repository_name" {
  description = "The name of the ECR repository."
  type        = string
}

resource "aws_ecr_repository" "repo" {
  name = var.repository_name
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

output "repository_url" {
  description = "The URL of the ECR repository."
  value       = aws_ecr_repository.repo.repository_url
}
