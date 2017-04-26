#!/bin/bash -ex

###################### prepare repo tool ######################
if [ ! -e bin ]; then
    mkdir -p bin;
    wget -c http://www.open-estuary.com/EstuaryDownloads/tools/repo -O bin/repo
    chmod a+x bin/repo;
fi

export PATH=${WORKSPACE}/bin:$PATH;

# sync
cd ~/estuary_reference

repo init -u "https://github.com/open-estuary/estuary.git" --mirror --no-repo-verify --repo-url=git://android.git.linaro.org/tools/repo

false; while [ $? -ne 0 ]; do repo sync --force-sync; done
repo status

print_time "the end time of finishing downloading estuary is "
