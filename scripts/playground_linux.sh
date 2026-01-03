curl -sf https://labs.iximiuz.com/cli/install.sh | sh

export PATH=$PATH:/home/crash/.iximiuz/labctl/bin
source ~/.bashrc 

labctl auth login
labctl playground start docker
labctl playground start ubuntu-24-04 --ssh
echo "labctl ssh <playground-id>"