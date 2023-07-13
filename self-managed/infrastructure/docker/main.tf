terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "3.0.2"
    }
  }
}

provider "docker" {
  host = "unix:///var/run/docker.sock"
}

# # Start a container
# resource "docker_container" "ubuntu" {
#   name  = "foo"
#   image = docker_image.ubuntu.image_id
# }

# # Find the latest Ubuntu precise image.
# resource "docker_image" "ubuntu" {
#   name = "ubuntu:precise"
# }



# data "docker_image" "base_image" {
#   name = "learn-consul/base-image:learn-consul"
#   keeplocally
# }

# resource "docker_registry_image"

resource "docker_network" "primary_network" {
  name = "learn-consul-network"
  labels {
    label = "tag"
    value = "learn-consul"
  }
}

resource "docker_container" "bastion_host" {
  name  = "bastion"
  image = "learn-consul/base-image:learn-consul"
  hostname = "bastion"
  # image = docker_image.base_image.image_id
  # provider = docker.world
  networks_advanced {
    name = docker_network.primary_network.id
  }
  labels {
    label = "tag"
    value = "learn-consul"
  }

}

resource "docker_container" "hashicups_nginx" {
  name  = "hashicups_nginx"
  image = "learn-consul/base-image:learn-consul"
  hostname = "hashicups-nginx"
  networks_advanced {
    name = docker_network.primary_network.id
  }
  labels {
    label = "tag"
    value = "learn-consul"
  }

}

resource "docker_container" "hashicups_frontend" {
  name  = "hashicups_frontend"
  image = "learn-consul/base-image:learn-consul"
  hostname = "hashicups-frontend"
  networks_advanced {
    name = docker_network.primary_network.id
  }
  labels {
    label = "tag"
    value = "learn-consul"
  }

}

resource "docker_container" "hashicups_api" {
  name  = "hashicups_api"
  image = "learn-consul/base-image:learn-consul"
  hostname = "hashicups-api"
  networks_advanced {
    name = docker_network.primary_network.id
  }
  labels {
    label = "tag"
    value = "learn-consul"
  }

}

resource "docker_container" "hashicups_db" {
  name  = "hashicups_db"
  image = "learn-consul/base-image:learn-consul"
  hostname = "hashicups-db"
  networks_advanced {
    name = docker_network.primary_network.id
  }
  labels {
    label = "tag"
    value = "learn-consul"
  }

}
