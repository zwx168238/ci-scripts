### This file is for installing the kernelci-backend 
#install ansible
sudo apt-get install software-properties-common
sudo apt-add-repository ppa:ansible/ansible
sudo apt-get update
sudo apt-get install ansible

git clone https://github.com/joyxu/kernelci-backend.git
cd kernelci-backend/ansible

#
#create ansible key
#
ssh-keygen
cat ~/.ssh/id_rsa.pub > ~/.ssh/authorized_keys

### modify the var.yaml according to the user needs
ansible-playbook -K -i hosts site.yml --skip-tags=backup,firewall,web-server -e @/home/joyxu/develop/hisilicon-ci/kernelci-backend/ansible/var.yml

#change the default token
curl -X POST -H "Content-Type: application/json" -H "Authorization: 123456" -d '{"email": "you@example.net", "admin": 1}' 192.168.1.108:8888/token
