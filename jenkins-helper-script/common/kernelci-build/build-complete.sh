#!/bin/bash

rm -rf *


if [ $PUBLISH != true ]; then
  echo "Skipping publish step.  PUBLISH != true."
  exit 0
fi

if [[ -z $TREE_NAME ]]; then
  echo "TREE_NAME not set.  Not publishing."
  exit 1
fi

if [[ -z $GIT_DESCRIBE ]]; then
  echo "GIT_DESCRIBE not set. Not publishing."
  exit 1
fi

if [[ -z $ARCH_LIST ]]; then
  echo "ARCH_LIST not set.  Not publishing."
  exit 1
fi

# Sanity prevails, do the copy
for arch in ${ARCH_LIST}; do
    BASEDIR=/var/www/images/kernel-ci/$TREE_NAME/$GIT_DESCRIBE
    sudo touch ${BASEDIR}/$arch.done
    sudo find ${BASEDIR} -type f -path "*/$arch-*" -fprint ${BASEDIR}/$arch.filelist
done

# Check if all builds for all architectures have finished. The magic number here is 3 (arm, arm64, x86)
# This magic number will need to be changed if new architectures are added.
export BUILDS_FINISHED=$(ls /var/www/images/kernel-ci/$TREE_NAME/$GIT_DESCRIBE/ | grep .done | wc -l)
if [[ BUILDS_FINISHED -eq 2 ]]; then
    echo "All builds have now finished, triggering testing..."
    # Tell the dashboard the job has finished build.
    echo "Build has now finished, reporting result to dashboard."
    curl -X POST -H "Authorization: db85d8fb-da63-4d77-950e-3dffcd8ce115" -H "Content-Type: application/json" -d '{"job": "'$TREE_NAME'", "kernel": "'$GIT_DESCRIBE'"}' http://192.168.3.100:8888/job
    curl -X POST -H "Authorization: db85d8fb-da63-4d77-950e-3dffcd8ce115" -H "Content-Type: application/json" -d '{"job": "'$TREE_NAME'", "kernel": "'$GIT_DESCRIBE'", "build_report": 1, "send_to": ["gabriele.paoloni@huawei.com", "charles.chenxin@huawei.com", "xavier.huwei@huawei.com", "majun258@huawei.com", "wangzhou1@hisilicon.com", "xuwei5@hisilicon.com", "liwenchang@hisilicon.com", "tangchaofei@huawei.com", "wanghuiqiang@huawei.com", "xuzaibo@huawei.com", "yuanzhichang@hisilicon.com", "yisen.zhuang@huawei.com", "zhangjukuo@huawei.com", "anurup.m@huawei.com", "john.garry@huawei.com", "shiju.jose@huawei.com", "dongyingjie@hisilicon.com", "salil.mehta@huawei.com"], "send_cc": ["yimin@huawei.com", "liguozhu@hisilicon.com", "zhaojunhua@hisilicon.com", "lixiaoping3@huawei.com", "z.liuxinliang@hisilicon.com", "kong.kongxinwei@hisilicon.com", "shameerali.kolothum.thodi@huawei.com", "sanil.kumar@hisilicon.com", "wangkefeng.wang@huawei.com", "guohanjun@huawei.com"], "format": ["txt", "html"], "delay": 10}' http://192.168.3.100:8888/send
fi