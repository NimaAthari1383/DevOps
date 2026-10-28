# Some Docker Commands

## Table Of Contents

- [Basic Commands](#basic-commands)
- [Docker Image](#docker-image)
- [Docker Compose](#docker-compose)
- [Docker Volume](#docker-volume)
- [Docker Network](#docker-network)
- [Docker Run](#docker-run)
- [Docker Ps](#docker-ps)
- [Docker Container](#docker-container)
- [Docker System](#docker-system)

---

## Basic Commands

| Command                                                                                                           | What it does                                                          | Description                                               |
|-------------------------------------------------------------------------------------------------------------------|-----------------------------------------------------------------------|-----------------------------------------------------------|
| `docker version`      | Shows docker installed details        |       |
| `docker info`     | Shows docker information details      |       |
| `systemctl edit docker`       | Edit docker config file details       | Config file is in /etc/systemd/system/docker.service.d/   |
| `docker logs SERVICE_NAME`        | Show SERVICE_NAME logs        |                                                           |
| `docker rm -f SERVICE_NAME`       |       |       |
| `docker exec`     | Can execute commands in a container       |       |
| `docker exec -it *mysql bash`     |       |       |
| `docker tag registry.gitlab.com/user/project:latest registry.gitlab.com/newuser/newrepo:newtag`       |       |       |
| `dcker save -o DESTINATION.tar PATH_TO_IMAGE/IMAGE:VERSION`       | Save docker image as a `.tar` file        |       |
| `docker load -i DESTINATION.tar`      | Loads image from `.tar` file      |       |
| `docker login registry.gitlab.com`        | Login by docker user      |       |
| `docker push SERVER_ADDRESS/PATH/IMAGE:VERSION`       | Save image in `SERVER_ADDRESS/PATH/IMAGE:VERSION`     |       |
| `docker push continer`        |       |       |
| `docker cp`       | Copy file from a container or to it       |       |
| `docker kill`     | Kills docker container        |       |
| `docker stats`        | Gets containers resources     |       |
| `docker system df`        | Gets docker disk resource     |       |

Docker Root Directory

***[🔝 Table Of Contents](#table-of-contents)***

---

## Docker Image

| Command                                                                                                           | What it does                                                          | Description                                               |
|-------------------------------------------------------------------------------------------------------------------|-----------------------------------------------------------------------|-----------------------------------------------------------|
| `docker images`       | Shows docker images       |       |
| `docker image load -i FILE.tar`       | Load image from a .tar file       |       |
| `docker image ls`       | List of docker images       |       |
| `docker image rm IMAGE`       | Remove docker image       |       |
| `docker image prune`      | Removes untaged docker images     |       |
| `docker image inspect`        | Shows docker images details       |       |
| `docker image history`        | Shows history of docker images creation       |       |
| `docker image pull`       | Pulls docker images from registry     |       |
| `docker image push`       | Pushs docker images to registry       |       |
| `docker image tag`        | Add tag to docker image       |       |
| `docker image rm`        | Remove docker image       |       |
| `docker image save`       | Export your container image       |       |
| `docker image load`       | Import your docker image to a container       |       |
| `docker image build -t *NAME`     | Buils docker imaage based on your Dockerfile config       |       |

***[🔝 Table Of Contents](#table-of-contents)***

---

## Docker Compose

| Command       | What it does      | Description       |
|---------------||------------------||------------------|
| `docker compose ls`       | Show docker compose file location     |       |
| `docker compose ps`       | Show docker containers status     |       |
| `docker compose ps -a`        | Show docker containers status     |       |
| `docker compose images`       | Shows docker images       |       |
| `docker compose build`        | Build compose file        |       |
| `docker compose up`       | Start creating container with compose file        |       |
| `docker compose up -d`        | Start creating container with compose file        |       |
| `docker compose up --force-recreate *COONTAINER_NAME`     | Start creating container with compose file and recreate container     |       |
| `docker compose down`     | Stop running container        |       |
| `docker compose down -V`      | Stop running container and remove container volumes       |       |
| `docker compose down --remove-orphans`        |       |       |
| `docker compose logs`     | Show logs     |       |
| `docker compose logs *COONTAINER_NAME --tail=100`     | Show COONTAINER_NAME logs     |       |
| `docker compose exec`     |       |       |
| `docker compose scale`        |       |       |
| `docker compose config`       | Syntax check and check configs        |       |

***[🔝 Table Of Contents](#table-of-contents)***

---

## Docker Volume

| Command                                                                                                           | What it does                                                          | Description                                               |
|-------------------------------------------------------------------------------------------------------------------|-----------------------------------------------------------------------|-----------------------------------------------------------|
| `docker volume ls`        | Shows docker volumes      |       |
| `docker volume inspect *mysql_data`       | Show mysql_data volume details        |       |
| `docker volume create`        |       |       |
| `docker volume prune`     |       |       |
| `docker volume rm`        |       |       |

***[🔝 Table Of Contents](#table-of-contents)***

---

## Docker Network

| Command                                                                                                           | What it does                                                          | Description                                               |
|-------------------------------------------------------------------------------------------------------------------|-----------------------------------------------------------------------|-----------------------------------------------------------|
| `docker network ls`       | List docker networks      |                                                           |
| `docker network create *elk_net`      | Create web_net docker network     |                                                           |
| `docker network create *web_net -o com.docker.network.bridge.name=*web_net`       | Create web_net docker network     |       |
| `docker network connect`      | Connect a network to another one      |                                                           |
| `docker network disconnect`       | Disconnect a network from another one     |                                                           |

***[🔝 Table Of Contents](#table-of-contents)***

---

## Docker Run

| Command           | What it does                      | Description       |
|-------------------|-----------------------------------|-------------------|
| `docker run`      | Run a container from image        |                   |
| `docker run -d --name mysql -e MYSQL_ROOT_PASSWORD=*P@SSW0RD mysql:5.7`       | Run a container from image with mysql name with MYSQL_ROOT_PASSWORD environment with image mysql:5.7      |       |
| `docker run –d --name mysql_container -v mysql_data:/var/lib/mysql -e MYSQL_ROOT_PASSWORD=*P@SSW0RD mysql:57`     | Run a container from image with mysql name with MYSQL_ROOT_PASSWORD environment with image mysql:5.7 with volume mysql_data which is mapped to /var/lib/mysql on container        |       |
| `docker run -itd --name *COONTAINER_NAME --hostnme *COONTAINER_NAME *busybox`                                     | Will create a container named COONTAINER_NAME with busybox image      |       |
| `docker run -itd --name *COONTAINER_NAME -p 7080:80 *busybox`     | Will create a container named COONTAINER_NAME which will map port 80 of container on port 7080 of host      |     |

***[🔝 Table Of Contents](#table-of-contents)***

---

## Docker Ps

| Command                                                                                                           | What it does                                                          | Description                                               |
|-------------------------------------------------------------------------------------------------------------------|-----------------------------------------------------------------------|-----------------------------------------------------------|
| `docker ps`       | Show running containers       |       |
| `docker ps a`     | Show died containers      |       |

***[🔝 Table Of Contents](#table-of-contents)***

---

## Docker Container

| Command       | What it does      | Description       |
|---------------|-------------------|-------------------|
| `docker container ls`     | Show running containers       |       |
| `docker container ls -a`      | Show died containers      |       |
| `docker container inspect *CONTAINER`     | Show running container detils     |       |
| `docker container cp *SRC_FILE *DST_SRV:/DST_PATH`     | Copy files from container or to it        |       |
| `docker container diff`       | Gets difference between container and our image. Its not history      |       |
| `docker container port`       | Gets ports listened or published on container      |       |
| `docker container prune`      | Removes unused containers |       |
| `docker container rename`     | Renames containers        |       |
| `docker container logs -f *CONTAINER`     | Get logs of containers        |       |
| `docker container stats`      | Get resources usage of containers     |       |
| `docker container rename`      | Change container's name     |       |
| `docker container commit`     | Export a container into a image       |       |
| `docker container exec`     |        |       |
| `docker container run -itd --name *CONTAINER_NAME --hostname *CONTAINER_NAME -p 80:80 *IMAGE_NAME`     |        |       |

***[🔝 Table Of Contents](#table-of-contents)***

---

## Docker System

| Command                                                                                                           | What it does                                                          | Description                                               |
|-------------------------------------------------------------------------------------------------------------------|-----------------------------------------------------------------------|-----------------------------------------------------------|
| `docker system info`      | Show docker info      |       |
| `docker system df`        | Show docker resource usage        |       |
| `docker system prune`     | Removes unued networks and resources      |       |

***[🔝 Table Of Contents](#table-of-contents)***

---

docker build -t ubuntu:tools .
