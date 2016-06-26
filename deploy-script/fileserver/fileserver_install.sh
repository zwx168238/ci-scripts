#!/bin/bash
##### file server #####
#create /var/www/images/kernerl-ci for storing the generated binaries
sudo mkdir -p /var/www/images/kernel-ci
sudo chmod -R 777 /var/www/images/kernel-ci
sudo chown -R www-data /var/www/images/kernel-ci

#create /srv/mirrors/linux.git
sudo mkdir -p /srv/mirrors
sudo git clone https://github.com/hisilicon/linux-hisi.git /srv/mirrors/linux.git

#file server for file-server
sudo apt-get install nginx
sudo cp kernelci-fileserver /etc/nginx/sites-available
sudo ln -s /etc/nginx/sites-available/kernelci-fileserver /etc/nginx/sites-enabled/kernelci-fileserver
sudo rm /etc/nginx/sites-enabled/default
sudo service nginx restart
