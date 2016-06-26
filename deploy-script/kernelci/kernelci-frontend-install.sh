#install ansible
sudo apt-get install software-properties-common
sudo apt-add-repository ppa:ansible/ansible
sudo apt-get update
sudo apt-get install ansible

#install uwsgi
#sudo apt-get install python-pip
#sudo pip install uwsgi
#sudo service uwsgi restart

#set below on the ssh server
#sudo sysctl -w net.core.somaxconn=4096

git clone https://github.com/open-estuary/ci-scripts.git -b openlab2.0
cd ci-scritps/deploy-script/kernelci/kernelci-frontend-config/
ansible-playbook --ask-pass --ask-sudo-pass -i hosts site.yml
