# Install and configuraion docker 

## Install requirements basic tools: 
sudo apt install wget git vim bash-completion curl htop net-tools dnsutils atop sudo software-properties-common telnet axel jq iotop ca-certificates curl gnupg lsb-release apt-transport-https gpg -y
 
## Get gpg key and add docker repositroy: 

### Add Docker’s official GPG key: 
 
sudo mkdir -p /etc/apt/keyrings
sudo chmod -R 0755 /etc/apt/keyrings 
sudo curl -fsSL "https://download.docker.com/linux/debian/gpg" | gpg --dearmor --yes -o /etc/apt/keyrings/docker.gpg 
 
# OR Download docker.gpg from mecan repository  
#curl -fsSL "https://repo.mecan.ir/repository/debian-docker/gpg" | gpg --dearmor --yes -o /etc/apt/keyrings/docker.gpg 
 

 
sudo chmod a+r /etc/apt/keyrings/docker.gpg 
 

## Set up the repository: 
sudo echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian bullseye stable" > /etc/apt/sources.list.d/docker.list 
cat /etc/apt/sources.list.d/docker.list 
 

# If apt mirror repository, add this line instead. We are using mirror `repo.mecan.ir`  repository.
#echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/docker.gpg] https://repo.mecan.ir/repository/debian-docker bookworm stable" > /etc/apt/sources.list.d/docker.list 
#cat /etc/apt/sources.list.d/docker.list 

# Update cache repository and install containerd: 
sudo apt-get update 

## Install Docker 
sudo apt install docker-ce docker-ce-cli containerd.io docker-compose-plugin docker-buildx-plugin docker-ce-rootless-extras docker-scan-plugin -y

## Configuration docker 
## Check docker config directory 
[[ -d /etc/docker ]] || sudo mkdir /etc/docker 

sudo cat << 'EOF' >> /etc/docker/daemon.json
{ "registry-mirrors": ["https://hub.mecan.ir","https://hub.hamdocker.ir"] } 
EOF


## Watch changes
cat /etc/docker/daemon.json 

## Restart docker service 
sudo systemctl restart docker 
sudo systemctl enable docker 
sudo systemctl status docker 


## To create the docker group and add your user: 

## Create the docker group:
sudo groupadd docker 


## Add your user to the docker group:
sudo usermod -aG docker $USER 
