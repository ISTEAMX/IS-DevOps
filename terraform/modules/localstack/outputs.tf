output "container_name" {
  description = "Name of the LocalStack container"
  value       = docker_container.localstack.name
}

output "container_id" {
  description = "ID of the LocalStack container"
  value       = docker_container.localstack.id
}
