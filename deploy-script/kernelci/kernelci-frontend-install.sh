##### this file is for installing the kernel-ci frontend
#install ansible
sudo apt-get install software-properties-common
sudo apt-add-repository ppa:ansible/ansible
sudo apt-get update
sudo apt-get install ansible

#install uwsgi
sudo apt-get install python-pip
sudo pip install uwsgi
sudo service uwsgi restart

git clone https://github.com/joyxu/kernelci-frontend.git
cd kernelci-frontend/ansible

#create ansible key
ssh-keygen
cat ~/.ssh/id_rsa.pub > ~/.ssh/authorized_keys

#please remember to change the var.yml about the token
# need to do it by manually
ansible-playbook -K -i hosts site.yml -e @/home/joyxu/develop/hisilicon-ci/kernelci-frontend/ansible/var.yml
