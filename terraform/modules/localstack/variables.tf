variable "container_name" {
  description = "Name of the LocalStack container"
  type        = string
  default     = "localstack-main"
}

variable "image" {
  description = "Docker image for LocalStack"
  type        = string
  default     = "localstack/localstack"
}

variable "ports" {
  description = "Port mappings for LocalStack"
  type = map(object({
    internal = number
    external = number
  }))
  default = {
    "legacy-edge" = {
      internal = 4566
      external = 4566
    },
    "s3" = {
      internal = 4572
      external = 4572
    }
  }
}

variable "networks" {
  description = "A list of networks to attach the container to"
  type        = list(string)
  default     = []
}
