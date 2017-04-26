#!/bin/bash
cd ${WORK_HOME}
docker run -d -p 2002:8080 -p 2003:50000 --name myjenkins -v ./jenkins_home/:/var/jenkins_home njdocker1.nj.thundersoft.com/public/jenkins
