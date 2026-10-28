# Install & Config Docker

## Install Basic Tools Requirements

 ```bash
    apt install wget git vim bash-completion curl htop net-tools dnsutils atop sudo software-properties-common telnet axel jq iotop ca-certificates curl gnupg lsb-release apt-transport-https gpg -y
```

## Get gpg key and add docker repositroy

Add Docker’s official GPG key:

```bash
sudo mkdir -p /etc/apt/keyrings
sudo chmod -R 0755 /etc/apt/keyrings 
curl -fsSL "https://download.docker.com/linux/debian/gpg" | gpg --dearmor --yes -o /etc/apt/keyrings/docker.gpg 
```

OR Download docker.gpg from mecan repository

```bash
curl -fsSL "https://repo.mecan.ir/repository/debian-docker/gpg" | gpg --dearmor --yes -o /etc/apt/keyrings/docker.gpg 
```

```bash
chmod a+r /etc/apt/keyrings/docker.gpg 
```

Set up the repository:

```bash
echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian bullseye stable" > /etc/apt/sources.list.d/docker.list 
cat /etc/apt/sources.list.d/docker.list 
```

If apt mirror repository, add this line instead. We are using mirror `repo.mecan.ir`  repository.

```bash
echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/docker.gpg] https://repo.mecan.ir/repository/debian-docker bookworm stable" > /etc/apt/sources.list.d/docker.list 
cat /etc/apt/sources.list.d/docker.list 
```

Update cache repository and install containerd:

```bash
sudo apt-get update 
```

### Install Docker

```bash
    apt install docker-ce docker-ce-cli containerd.io docker-compose-plugin docker-buildx-plugin docker-ce-rootless-extras docker-scan-plugin -y
```

### Configuration docker

```bash
# Check docker config directory 
[[ -d /etc/docker ]] || mkdir /etc/docker 

sudo vim /etc/docker/daemon.json 
# Add registry mirrors
<SOF>
{ "registry-mirrors": ["https://hub.mecan.ir","https://hub.hamdocker.ir"] } 
<EOF>

# Watch changes
cat /etc/docker/daemon.json 
{ "registry-mirrors": ["https://hub.mecan.ir","https://hub.hamdocker.ir"] } 

# Restart docker service 
systemctl restart docker 
systemctl enable docker 
systemctl status docker 
```

### To create the docker group and add your user

Create the docker group:

```bash
sudo groupadd docker 
```

Add your user to the docker group:

```bash
sudo usermod -aG docker $USER 
```
