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

# ----------------- #
# | NETEWORK      | #
# ----------------- #

resource "docker_network" "primary_network" {
  name = "learn-consul-network"
  labels {
    label = "tag"
    value = "learn-consul"
  }
}

# ----------------- #
# | PREREQUISITES | #
# ----------------- #

resource "docker_container" "bastion_host" {
  name     = "bastion"
  image    = "learn-consul/base-consul:learn-consul"
  hostname = "bastion"
  # image = docker_image.base_image.image_id
  # provider = docker.world
  networks_advanced {
    name = docker_network.primary_network.id
  }

  ports {
    internal = "22"
    external = "8022"
  }

  labels {
    label = "tag"
    value = "learn-consul"
  }

  connection {
    type        = "ssh"
    user        = "admin"
    private_key = file("./images/base/certs/id_rsa")
    host        = "127.0.0.1"
    port        = 8022
  }

  provisioner "file" {
    source      = "${path.module}/../../../assets"
    destination = "/home/admin/"
  }

  provisioner "file" {
    source      = "${path.module}/../../ops"
    destination = "/home/admin"
  }

  provisioner "remote-exec" {
    inline = [
      "cd /home/admin/ops && bash ./provision.sh operate ${var.scenario}"
    ]
  }

}

# ----------------- #
# | CONTROL PLANE | #
# ----------------- #

resource "docker_container" "consul_server" {
  name     = "consul-server-${count.index}"
  count    = var.server_number
  image    = "learn-consul/base-consul:learn-consul"
  hostname = "consul-server-${count.index}"
  # image = docker_image.base_image.image_id
  # provider = docker.world
  networks_advanced {
    name = docker_network.primary_network.id
  }
  labels {
    label = "tag"
    value = "learn-consul"
  }

  ports {
    internal = "8443"
    external = format("%d", count.index + 8443)
  }

}

# ----------------- #
# | GATEWAY       | #
# ----------------- #

resource "docker_container" "gateway_api" {
  name     = "gateway_api"
  image    = "learn-consul/base-consul:learn-consul"
  hostname = "gateway-api"
  # image = docker_image.base_image.image_id
  # provider = docker.world
  networks_advanced {
    name = docker_network.primary_network.id
  }
  labels {
    label = "tag"
    value = "learn-consul"
  }

  ports {
    internal = "8443"
    external = "9443"
  }

}

# ----------------- #
# | DATA PLANE    | #
# ----------------- #


resource "docker_container" "hashicups_nginx" {
  name     = "hashicups_nginx"
  image    = "learn-consul/hashicups-nginx:learn-consul"
  hostname = "hashicups-nginx"
  networks_advanced {
    name = docker_network.primary_network.id
  }
  labels {
    label = "tag"
    value = "learn-consul"
  }

  ports {
    internal = "80"
    external = "80"
  }

}

resource "docker_container" "hashicups_frontend" {
  name     = "hashicups_frontend"
  image    = "learn-consul/hashicups-frontend:learn-consul"
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
  name     = "hashicups_api"
  image    = "learn-consul/hashicups-api:learn-consul"
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
  name     = "hashicups_db"
  image    = "learn-consul/hashicups-database:learn-consul"
  hostname = "hashicups-db"
  networks_advanced {
    name = docker_network.primary_network.id
  }
  labels {
    label = "tag"
    value = "learn-consul"
  }

}


# ----------------- #
# | MONITORING    | #
# ----------------- #

resource "docker_container" "grafana" {
  name     = "grafana"
  image    = "grafana/grafana:latest"
  hostname = "grafana"

  networks_advanced {
    name = docker_network.primary_network.id
  }

  labels {
    label = "tag"
    value = "learn-consul"
  }

  ports {
    internal = "3000"
    external = "3000"
  }

  volumes {
    host_path      = abspath("${path.module}/../../../assets/templates/conf/grafana/provisioning/datasources")
    container_path = "/etc/grafana/provisioning/datasources"
  }

  volumes {
    host_path      = abspath("${path.module}/../../../assets/templates/conf/grafana/provisioning/dashboards")
    container_path = "/etc/grafana/provisioning/dashboards"
  }

  volumes {
    host_path      = abspath("${path.module}/../../../assets/templates/conf/grafana/dashboards")
    container_path = "/var/lib/grafana/dashboards"
  }

  env = [
    "GF_AUTH_ANONYMOUS_ENABLED=true",
    "GF_AUTH_ANONYMOUS_ORG_ROLE=Admin",
    "GF_AUTH_DISABLE_LOGIN_FORM=true"
  ]

}

resource "docker_container" "loki" {
  name     = "loki"
  image    = "grafana/loki:main"
  hostname = "loki"

  networks_advanced {
    name = docker_network.primary_network.id
  }

  labels {
    label = "tag"
    value = "learn-consul"
  }

  command = ["-config.file=/etc/loki/local-config.yaml"]

}

resource "docker_container" "mimir" {
  name     = "mimir"
  image    = "grafana/mimir:latest"
  hostname = "mimir"
  networks_advanced {
    name = docker_network.primary_network.id
  }

  labels {
    label = "tag"
    value = "learn-consul"
  }

  volumes {
    host_path      = abspath("${path.module}/../../../assets/templates/conf/mimir/mimir.yaml")
    container_path = "/etc/mimir/mimir.yaml"
  }

  command = ["--config.file=/etc/mimir/mimir.yaml"]
}