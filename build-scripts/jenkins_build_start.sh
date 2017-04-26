#!/bin/bash -ex
function init_workspace() {
    WORKSPACE=${WORKSPACE:-~/estuary/WORKSPACE}
    mkdir -p ${WORKSPACE}
}

function init_env_params() {
    WORK_DIR=${WORKSPACE}/local
    CI_SCRIPTS_DIR=${WORK_DIR}/ci-scripts
    CODE_REFERENCE=/home/ubuntu/estuary_reference
}

function init_build_env() {
    LANG=C
    PATH=${CI_SCRIPTS_DIR}/build-scripts:$PATH

    CPU_NUM=$(cat /proc/cpuinfo | grep processor | wc -l)
    OPEN_ESTUARY_DIR=${WORK_DIR}/open-estuary
    BUILD_DIR=${OPEN_ESTUARY_DIR}/build
    ESTUARY_CFG_FILE=${OPEN_ESTUARY_DIR}/estuary/estuarycfg.json
}

function init_input_params() {
    TREE_NAME=open-estuary
    SHELL_PLATFORM="D05"
    SHELL_DISTRO="Ubuntu"
    ARCH_MAP="d05 arm64"
    BOOT_PLAN=""
    APP_PLAN=""
    USER="yangyang"
    HOST="192.168.67.123"
    LAVA_SERVER=""
    LAVA_STREAM=""
    LAVA_TOKEN=""
    KERNELCI_SERVER=""
    KERNELCI_TOKEN=""
    FTP_SERVER=""
    FTP_DIR="/var/www/images/kernel-ci"
    TFTP_DIR="/var/lib/tftpboot"
    VERSION=""
    LAVA_USER=""
    PACKAGES=""
    SETUP_TYPE=""
}

function parse_params() {
    pushd ${CI_SCRIPTS_DIR}/boot-app-scripts    # change current work directory
    : ${SHELL_PLATFORM:=`python parameter_parser.py -f config.yaml -s Build -k Platform`}
    : ${SHELL_DISTRO:=`python parameter_parser.py -f config.yaml -s Build -k Distro`}

    : ${BOOT_PLAN:=`python parameter_parser.py -f config.yaml -s Jenkins -k Boot`}
    : ${APP_PLAN:=`python parameter_parser.py -f config.yaml -s Jenkins -k App`}

    : ${USER:=`python parameter_parser.py -f config.yaml -s LAVA -k USER`}
    : ${HOST:=`python parameter_parser.py -f config.yaml -s LAVA -k HOST`}

    : ${LAVA_SERVER:=`python parameter_parser.py -f config.yaml -s LAVA -k lavaserver`}
    : ${LAVA_USER:=`python parameter_parser.py -f config.yaml -s LAVA -k lavauser`}
    : ${LAVA_STREAM:=`python parameter_parser.py -f config.yaml -s LAVA -k lavastream`}
    : ${LAVA_TOKEN:=`python parameter_parser.py -f config.yaml -s LAVA -k TOKEN`}

    : ${KERNELCI_SERVER:=`python parameter_parser.py -f config.yaml -s Kernelci -k server`}
    : ${KERNELCI_TOKEN:=`python parameter_parser.py -f config.yaml -s Kernelci -k token`}

    : ${FTP_SERVER:=`python parameter_parser.py -f config.yaml -s Kernelci -k ftpserver`}

    echo $ARCH_MAP
    : ${ARCH_MAP:=`python parameter_parser.py -f config.yaml -s Arch`}
    echo $ARCH_MAP

    popd    # restore current work directory
}

function save_to_properties() {
    cat << EOF > ${WORKSPACE}/env.properties
GIT_DESCRIBE=$GIT_DESCRIBE
SHELL_PLATFORM=$SHELL_PLATFORM
SHELL_DISTRO=$SHELL_DISTRO
BOOT_PLAN=$BOOT_PLAN
APP_PLAN=$APP_PLAN
USER=$USER
HOST=$HOST
LAVA_SERVER=$LAVA_SERVER
LAVA_USER=$LAVA_USER
LAVA_STREAM=$LAVA_STREAM
LAVA_TOKEN=$LAVA_TOKEN
KERNELCI_SERVER=$KERNELCI_SERVER
KERNELCI_TOKEN=$KERNELCI_TOKEN
FTP_SERVER=$FTP_SERVER
ARCH_MAP=$ARCH_MAP
TFTP_DIR=$TFTP_DIR
EOF
    # EXECUTE_STATUS="Failure"x
    cat ${WORKSPACE}/env.properties
}

function show_properties() {
    cat ${WORKSPACE}/env.properties
}

function print_time() {
    init_timefile
    echo  $@ `date "+%Y-%m-%d %H:%M:%S"` >> $timefile
}

function init_timefile() {
    timefile=${WORKSPACE}/timestamp.log
    if [ -f $timefile ]; then
        rm -fr $timefile
    else
        touch $timefile
    fi
}

function prepare_repo_tool() {
    pushd $WORK_DIR
    if [ ! -e bin ]; then
        mkdir -p bin;
        wget -c http://www.open-estuary.com/EstuaryDownloads/tools/repo -O bin/repo
        chmod a+x bin/repo;
    fi
    export PATH=${WORK_DIR}/bin:$PATH;
    popd
}

function prepare_yaml_tool() {
    dev_tools="python-yaml"

    if ! (dpkg-query -l $dev_tools >/dev/null 2>&1); then
        sudo apt-get update
        if ! (sudo apt-get install -y --force-yes $dev_tools); then
            return 1
        fi
    fi
}

function sync_code() {
    mkdir -p $OPEN_ESTUARY_DIR;

    pushd $OPEN_ESTUARY_DIR;    # enter OPEN_ESTUARY_DIR

    # sync and checkout files from repo
    #repo init
    repo forall -c git reset --hard || true
    repo forall -c git clean -dxf || true

    if [ "$VERSION"x != ""x ]; then
        repo init -u "https://github.com/open-estuary/estuary.git" \
             --reference=${CODE_REFERENCE} \
             -b refs/tags/$VERSION --no-repo-verify --repo-url=git://android.git.linaro.org/tools/repo
    else
        repo init -u "https://github.com/open-estuary/estuary.git" \
             --reference=${CODE_REFERENCE} \
             -b master --no-repo-verify --repo-url=git://android.git.linaro.org/tools/repo
    fi

    set +e
    false; while [ $? -ne 0 ]; do repo sync --force-sync; done
    set -e

    repo status

    print_time "the end time of finishing downloading estuary is "

    popd
}

function do_build() {
    pushd $OPEN_ESTUARY_DIR;    # enter OPEN_ESTUARY_DIR

    BUILD_CFG_FILE=/tmp/estuarycfg.json
    cp $ESTUARY_CFG_FILE $BUILD_CFG_FILE

    # Set all platforms support to "no"
    sed -i -e '/platform/s/yes/no/' $BUILD_CFG_FILE

    # Make platforms supported to "yes"
    echo $SHELL_PLATFORM
    for PLATFORM in $SHELL_PLATFORM
    do
        sed -i -e "/$PLATFORM/s/no/yes/" $BUILD_CFG_FILE
    done

    # Set all distros support to "no"
    distros=(Ubuntu OpenSuse Fedora Debian CentOS Rancher OpenEmbedded)
    for ((i=0; i<${#distros[@]}; i++))
    do
        sed -i -e "/${distros[$i]}/s/yes/no/" $BUILD_CFG_FILE
    done

    # Make distros supported to "yes"
    echo $SHELL_DISTRO
    for DISTRO in $SHELL_DISTRO
    do
        sed -i -e "/$DISTRO/s/no/yes/" $BUILD_CFG_FILE
    done

    # Set all packages supported to yes
    echo $PACKAGES
    for package in $PACKAGES
    do
        sed -i -e "/${package}/s/no/yes/" $BUILD_CFG_FILE
    done

    # Set all setup types supported to "no"
    echo $SETUP_TYPE
    for setuptype in $SETUP_TYPE
    do
        sed -i -e "/${setuptype}/s/yes/no/" $BUILD_CFG_FILE
    done

    cat $BUILD_CFG_FILE

    # Execute build
    ./estuary/build.sh --file=$BUILD_CFG_FILE --builddir=$BUILD_DIR
    if [ $? -ne 0 ]; then
        echo "estuary build failed!"
        exit -1
    fi

    print_time "the end time of estuary build is "

    popd

}

function get_version_info() {
    pushd $OPEN_ESTUARY_DIR;    # enter OPEN_ESTUARY_DIR

    if [ "$VERSION"x != ""x ]; then
        GIT_DESCRIBE=$VERSION
    else
        #### get uefi commit
        pushd uefi
        UEFI_GIT_DESCRIBE=$(git log --oneline | head -1 | awk '{print $1}')
        UEFI_GIT_DESCRIBE=uefi_${UEFI_GIT_DESCRIBE:0:7}
        popd

        #### get kernel commit
        pushd kernel
        KERNEL_GIT_DESCRIBE=$(git log --oneline | head -1 | awk '{print $1}')
        KERNEL_GIT_DESCRIBE=kernel_${KERNEL_GIT_DESCRIBE:0:7}
        popd

        #### get grub commit
        pushd grub
        GURB_GIT_DESCRIBE=$(git log --oneline | head -1 | awk '{print $1}')
        GURB_GIT_DESCRIBE=grub_${GURB_GIT_DESCRIBE:0:7}
        popd

        GIT_DESCRIBE=${UEFI_GIT_DESCRIBE}_${GURB_GIT_DESCRIBE}_${KERNEL_GIT_DESCRIBE}
    fi

    echo $GIT_DESCRIBE

    popd
}


function cp_image() {
    pushd $OPEN_ESTUARY_DIR;    # enter OPEN_ESTUARY_DIR

    DEPLOY_UTILS_FILE=deploy-utils.tar.bz2
    MINI_ROOTFS_FILE=mini-rootfs.cpio.gz
    GRUB_IMG_FILE=grubaa64.efi
    GRUB_CFG_FILE=grub.cfg
    KERNEL_IMG_FILE=Image
    TOOLCHAIN_FILE=gcc-linaro-aarch64-linux-gnu-4.9-2014.09_linux.tar.xz

    DES_DIR=$FTP_DIR/$TREE_NAME/$GIT_DESCRIBE
    [ -d $DES_DIR ] && sudo rm -rf $DES_DIR
    sudo mkdir -p $DES_DIR

    sudo cp $timefile $DES_DIR

    read -a arch_map <<< $(echo $ARCH_MAP)
    declare -A arch
    for((i=0; i<${#arch_map[@]}; i++))
    do
        if ((i%2==0)); then
            j=`expr $i+1`
            arch[${arch_map[$i]}]=${arch_map[$j]}
        fi
    done

    ls -l $BUILD_DIR
    pushd $BUILD_DIR  # enter BUILD_DIR

    # copy arch files
    pushd binary
    for arch_dir in arm*;do
        sudo mkdir -p $DES_DIR/$arch_dir
        sudo cp $arch_dir/* $DES_DIR/$arch_dir
    done
    popd

    # copy platfom files
    for PLATFORM in $SHELL_PLATFORM;do
        echo $PLATFORM

        PLATFORM_L="$(echo $PLATFORM | tr '[:upper:]' '[:lower:]')"
        PLATFORM_ARCH_DIR=$DES_DIR/${PLATFORM_L}-${arch[$PLATFORM_L]}
        [ -d $PLATFORM_ARCH_DIR ] && sudo rm -fr $PLATFORM_ARCH_DIR
        sudo mkdir -p ${PLATFORM_ARCH_DIR}/{binary,toolchain,distro}

        # copy toolchain files
        pushd $PLATFORM_ARCH_DIR/toolchain
        sudo ln -s ../../${arch[$PLATFORM_L]}/$TOOLCHAIN_FILE
        popd

        # copy binary files
        sudo find binary/$PLATFORM/ -type l -exec rm {} \; # remove symlinks
        sudo cp -rf binary/$PLATFORM/* $PLATFORM_ARCH_DIR/binary

        pushd $PLATFORM_ARCH_DIR/binary
        sudo ln -s ../../${arch[$PLATFORM_L]}/$KERNEL_IMG_FILE ${KERNEL_IMG_FILE}_${PLATFORM}
        sudo ln -s ../../${arch[$PLATFORM_L]}/$DEPLOY_UTILS_FILE
        sudo ln -s ../../${arch[$PLATFORM_L]}/$MINI_ROOTFS_FILE
        sudo ln -s ../../${arch[$PLATFORM_L]}/$GRUB_IMG_FILE
        sudo ln -s ../../${arch[$PLATFORM_L]}/$GRUB_CFG_FILE
        popd

        # copy distro files
        for DISTRO in $SHELL_DISTRO;do
            echo $DISTRO

            pushd ${CI_SCRIPTS_DIR}/boot-app-scripts
            distro_tar_name=`python parameter_parser.py -f config.yaml -s DISTRO -k $PLATFORM -v $DISTRO`
            popd

            if [ x"$distro_tar_name" = x"" ]; then
                continue
            fi

            echo $distro_tar_name

            pushd $DES_DIR/${arch[$PLATFORM_L]}
            [ ! -f ${distro_tar_name}.sum ] && sudo sh -c "md5sum $distro_tar_name > ${distro_tar_name}.sum"
            popd

            pushd $PLATFORM_ARCH_DIR/distro
            sudo ln -s ../../${arch[$PLATFORM_L]}/$distro_tar_name
            sudo ln -s ../../${arch[$PLATFORM_L]}/$distro_tar_name.sum
            popd
        done
    done

    popd  # leave BUILD_DIR
    sudo rm -fr $BUILD_DIR

    popd  # leave OPEN_ESTUARY_DIR
}

function main() {
    init_workspace
    init_env_params
    init_build_env

    init_input_params

    parse_params
    save_to_properties
    show_properties

    print_time "the begin time is "
    prepare_repo_tool

    sync_code
    do_build
    get_version_info
    cp_image
    save_to_properties
}

main
