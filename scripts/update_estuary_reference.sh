#!/bin/bash -ex
trap "exit 1" SIGINT SIGTERM

###################### prepare repo tool ######################
if [ ! -e bin ]; then
    mkdir -p bin;
    wget -c http://www.open-estuary.com/EstuaryDownloads/tools/repo -O bin/repo
    chmod a+x bin/repo;
fi

export PATH=${WORKSPACE}/bin:$PATH;

# sync
mkdir -p ~/estuary_reference
cd ~/estuary_reference

if [ ! -d '.repo' ];then
    repo init -u "https://github.com/open-estuary/estuary.git" --mirror --no-repo-verify --repo-url=git://android.git.linaro.org/tools/repo
fi

set +e
false; while [ $? -ne 0 ]; do repo sync --force-sync; done
set -e

repo status

print_time "the end time of finishing downloading estuary is "
