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

#import the job for the jenkins
java -jar jenkins-cli.jar -s http://localhost:8082/ create-job trigger-flex < hisilicon-script/trigger-flex.xml
java -jar jenkins-cli.jar -s http://localhost:8082/ create-job khilman-kbuilder < hisilicon-script/khilman-kbuilder.xml
java -jar jenkins-cli.jar -s http://localhost:8082/ create-job khilman-kernel-build-complete < hisilicon-script/khilman-kernel-build-complete.xml
