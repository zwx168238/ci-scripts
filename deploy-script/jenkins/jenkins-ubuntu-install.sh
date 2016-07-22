##### jenkins #####
# https://wiki.jenkins-ci.org/display/JENKINS/Installing+Jenkins+on+Ubuntu
wget -q -O - https://jenkins-ci.org/debian/jenkins-ci.org.key | sudo apt-key add -
sudo sh -c 'echo deb http://pkg.jenkins-ci.org/debian binary/ > /etc/apt/sources.list.d/jenkins.list'
sudo apt-get update
sudo apt-get install openjdk-7-jre openjdk-7-jdk jenkins

#change the port to 8082 of jenkins
sudo sed -i -- 's/HTTP_PORT=.*/\HTTP_PORT=8082/g' /etc/default/jenkins
sudo service jenkins restart

#install the plugin in the GUI
#- Manage Jenkins - Manage Plugins - Install "Git Plugin" - Install "Parameterized Trigger Plugin"
#- DynamicAxis Plugin - Build Environment Plugin - Environment Script Plugin - Workspace Cleanup Plugin - EnvInject Plugin
#- Matrix Project Plugin - build timeout plugin - Environment Injector Plugin 
#- Timestamper

echo "sleep 90 seconds to wait jenkins restart"
sleep 90

#install jenkins job builder
sudo apt-get install -y python-pip
sudo pip install jenkins-job-builder

#import the jobs
git clone -b openlab2 https://github.com/open-estuary/ci-scripts.git
cd ci-scripts/jenkins-job-config/
jenkins-jobs --conf ../deploy-script/jenkins/etc/jenkins_jobs.ini update  khilman-trigger-flex.yaml
jenkins-jobs --conf ../deploy-script/jenkins/etc/jenkins_jobs.ini update  khilman-kbuilder.yaml
jenkins-jobs --conf ../deploy-script/jenkins/etc/jenkins_jobs.ini update  khilmna-kernel-build-complete.yaml
jenkins-jobs --conf ../deploy-script/jenkins/etc/jenkins_jobs.ini update  kernelci-kboot-bot.yaml

#create /var/www/images/kernerl-ci 
sudo mkdir -p /var/www/images/kernel-ci
sudo chmod -R 777 /var/www/images/kernel-ci
sudo chown -R www-data /var/www/images/kernel-ci

#create /srv/mirrors/linux.git
sudo mkdir -p /srv/mirrors
sudo git clone https://github.com/hisilicon/linux-hisi.git /srv/mirrors/linux.git

#file server
sudo apt-get install nginx
sudo cp kernelci-fileserver /etc/nginx/sites-available
sudo ln -s /etc/nginx/sites-available/kernelci-fileserver /etc/nginx/sites-enabled/kernelci-fileserver
sudo rm /etc/nginx/sites-enabled/default
sudo service nginx restart
