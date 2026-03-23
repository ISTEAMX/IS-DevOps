terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}

resource "docker_image" "localstack" {
  name = var.image
}

resource "docker_container" "localstack" {
  name  = var.container_name
  image = docker_image.localstack.image_id
  env = [
    "LOCALSTACK_ACKNOWLEDGE_ACCOUNT_REQUIREMENT=1"
  ]
  networks_advanced {
    name = var.networks[0]
  }

  ports {
    internal = var.ports["legacy-edge"].internal
    external = var.ports["legacy-edge"].external
  }

  ports {
    internal = var.ports["s3"].internal
    external = var.ports["s3"].external
  }
}
