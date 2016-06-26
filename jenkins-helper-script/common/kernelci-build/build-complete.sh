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
if [[ BUILDS_FINISHED -eq 1 ]]; then
    echo "All builds have now finished, triggering testing..."
    # Tell the dashboard the job has finished build.
    echo "Build has now finished, reporting result to dashboard."
    curl -X POST -H "Authorization: db85d8fb-da63-4d77-950e-3dffcd8ce115" -H "Content-Type: application/json" -d '{"job": "'$TREE_NAME'", "kernel": "'$GIT_DESCRIBE'"}' http://192.168.3.100:8888/job
fi
