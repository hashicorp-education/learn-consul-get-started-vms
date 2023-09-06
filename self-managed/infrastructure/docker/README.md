# Consul on Docker with terraform

Deploys infrastructure for Consul test environments on Docker using Terraform.

## Docker Images

The `images` folder contains a set of definitions for the Docker images used in the scenario.

The following images are defined:

|    IMAGE NAME      | CONTENT |
| -----------------: | ------- |
| base               | `debian:latest` + SSL Certs + user + tools + SSH srv
| base-consul        | `base` + Consul + Envoy + Grafana Agent
| hashicups-api      | `base-consul` + `hashicorpdemoapp/*-api`
| hashicups-database | `base-consul` + postgres + config
| hashicups-frontend | `base-consul` + `im2nguyenhashi/frontend-localhost:latest`
| hashicups-nginx    | `base-consul` + NGINX + config

### Build Docker Images

The `images folder contains also two scripts useful for managing the images:
* `build_images.sh`
* `generate_variables.sh`

You can use them in combination to build images with the latest version of Consul and the highest supported Envoy version.

```
./generate_variables.sh && ./build_images.sh
```

> 🚧 -- The `./generate_variables.sh` script requires GNU tools and might not work on OSx out of the box.

Verify images after build:

```
docker images --filter=reference="*/*:learn-consul" --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}"
```

```
REPOSITORY                        TAG            SIZE
learn-consul/hashicups-nginx      learn-consul   1.36GB
learn-consul/hashicups-frontend   learn-consul   2.07GB
learn-consul/hashicups-api        learn-consul   2.03GB
learn-consul/hashicups-database   learn-consul   1.71GB
learn-consul/base-consul          learn-consul   1.33GB
learn-consul/base-image           learn-consul   320MB
```

## Available Scenarios

The scenarios available so far are the ones that cover the [Consul getting started for VMs](https://developer.hashicorp.com/consul/tutorials/get-started-vms/virtual-machine-gs-deploy) collection.

Scenarios available are stored under `./self-managed/ops/scenarios`.

You can check available scenarios from the tool itself:
```
./provision.sh list_scenarios
```

Scenarios are described in [this page](https://github.com/hashicorp-education/learn-consul-get-started-vms/blob/main/README.md#scenarios).

## Deploy Infrastructure



```
terraform destroy --auto-approve && \
    terraform apply --auto-approve -var-file=./conf/00_hashicups.tfvars
```

### Docker Instructions

- Clone repository (this branch)
- Enter repository folder
  ```
  cd learn-consul-get-started-vms/self-managed/infrastructure/docker` 
  ```
- Build Docker images for the scenario
  - Get into `images` folder
    ```
    cd ./images
    ``` 
  - Build Docker images
    ```
    ./build_images.sh
    ``` 
  - Check created images
     ```
    docker images --filter=reference="*/*:learn-consul"
    ```
    ```plaintext
    REPOSITORY                        TAG            IMAGE ID       CREATED        SIZE
    learn-consul/hashicups-nginx      learn-consul   baa60bfa5c57   27 hours ago   1.36GB
    learn-consul/hashicups-frontend   learn-consul   686439793736   27 hours ago   2.07GB
    learn-consul/hashicups-api        learn-consul   9ac3548db0ef   27 hours ago   2.03GB
    learn-consul/hashicups-database   learn-consul   817015bacbbe   27 hours ago   1.71GB
    learn-consul/base-consul          learn-consul   32b18547cc97   27 hours ago   1.33GB
    learn-consul/base-image           learn-consul   0d49a4845470   27 hours ago   320MB
    ```
- Spin up infrstructure
  - Initialize terraform
    ```
    terraform fmt && terraform init && terraform plan
    ``` 
  - Deploy Scenario 00 (prerequisite for [Tutorial1 GS](https://developer.hashicorp.com/consul/tutorials/get-started-vms/virtual-machine-gs-deploy))
    ```
    terraform apply --auto-approve -var-file=./conf/00_hashicups.tfvars
    ```
  - Verify containers are running
    ```
     docker ps --filter=label=tag="learn-consul" --format "table {{.Names}}\t{{.Ports}}\t{{.Image}}"
    ```
    ```
    NAMES                PORTS                    IMAGE
    bastion              0.0.0.0:8022->22/tcp     learn-consul/base-consul:learn-consul
    consul-server-0      0.0.0.0:8443->8443/tcp   learn-consul/base-consul:learn-consul
    consul-server-1      0.0.0.0:8444->8443/tcp   learn-consul/base-consul:learn-consul
    consul-server-2      0.0.0.0:8445->8443/tcp   learn-consul/base-consul:learn-consul
    gateway_api          0.0.0.0:9443->8443/tcp   learn-consul/base-consul:learn-consul
    grafana              0.0.0.0:3000->3000/tcp   grafana/grafana:latest
    hashicups_api        8080/tcp                 learn-consul/hashicups-api:learn-consul
    hashicups_db         5432/tcp                 learn-consul/hashicups-database:learn-consul
    hashicups_frontend   3000/tcp                 learn-consul/hashicups-frontend:learn-consul
    hashicups_nginx      0.0.0.0:80->80/tcp       learn-consul/hashicups-nginx:learn-consul
    loki                 3100/tcp                 grafana/loki:main
    mimir                8080/tcp                 grafana/mimir:latest
    ```
- Destroy infrastructure
  ```
  terraform destroy --auto-approve
  ```

## Play time (Docker version)

Once the deploy completes you can follow the GS tutorial or move around the environment.

Here some quick commands to move around the scenario:

* Login into Bastion Host
  ```
  docker exec -it bastion bin/bash
  ```
* Login into Bastion host as user admin (unprivileged user)

  ```
  docker exec -it -u admin bastion bin/bash
  ```

* Connect to containers via SSH
  From bastion host you can SSH without password on all other nodes. You can use Docker hostnames for connection.
  Example:
  ```
  ssh  admin@consul-server-0
  ```
  ```
  The authenticity of host 'consul-server-0 (172.21.0.5)' can't be established.
  ED25519 key fingerprint is SHA256:FUGkXFTpNyB6U2ygO/UD/Gp/k4cLvCxXke2ijwF0Mtc.
  Are you sure you want to continue connecting (yes/no/[fingerprint])? yes
  Warning: Permanently added 'consul-server-0' (ED25519) to the list of known hosts.
  
  The programs included with the Debian GNU/Linux system are free software;
  the exact distribution terms for each program are described in the
  individual files in /usr/share/doc/*/copyright.
  
  Debian GNU/Linux comes with ABSOLUTELY NO WARRANTY, to the extent
  permitted by applicable law.
  🔵 [0] admin@consul-server-0: ~ $
  ```