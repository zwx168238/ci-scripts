### this is a readme for Ubuntu14.04, 
### For the newest installation, please refer to the http://www.linaro.org/projects/test-validation/ 
gpg --keyserver pgpkeys.mit.edu --recv-key  8B48AD6246925553      
gpg -a --export 8B48AD6246925553 | sudo apt-key add -


gpg --keyserver pgpkeys.mit.edu --recv-key  7638D0442B90D010      
gpg -a --export 7638D0442B90D010 | sudo apt-key add -

deb [arch=amd64] http://images.validation.linaro.org/trusty-repo trusty main
$ wget http://images.validation.linaro.org/trusty-repo/trusty-repo.key.asc
$ sudo apt-key add trusty-repo.key.asc
$ sudo apt-get update

$ sudo apt-get install postgresql
$ sudo apt-get install lava
$ sudo a2dissite 000-USERNAME
$ sudo a2ensite lava-server.conf
$ sudo service apache2 restart

sudo lava-server manage createsuperuser --username USERNAME --email=$EMAIL
[Authentication Tokens]


$ sudo apt-get update
$ sudo apt-get install lava-tool
$ lava-tool auth-add http://USERNAME@192.168.1.106/RPC2/
Paste token for http://USERNAME@192.168.1.106/RPC2/:
Please set a password for your new keyring:
Please confirm the password:
Token added successfully for user <username>.

lava-tool make-stream --dashboard-url http://USERNAME@192.168.1.106/RPC2/ /anonymous/USERNAME/

