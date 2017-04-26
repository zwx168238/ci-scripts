#!/bin/bash
source env
cd ${WORK_HOME}
mkdir -p ${WORK_HOME}/jenkins_home
chmod a+r ${WORK_HOME}/jenkins_home
docker run --rm -d -p 2002:8080 -p 2003:50000 --name myjenkins -v ${WORK_HOME}/jenkins_home/:/var/jenkins_home njdocker1.nj.thundersoft.com/public/jenkins:2.32.3
