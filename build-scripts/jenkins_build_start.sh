#!/bin/bash -ex
# the server need open mode :
# modprobe loop
# export CODE_REFERENCE=""

# prepare system tools
function prepare_tools() {
    dev_tools="python-yaml"

    if ! (dpkg-query -l $dev_tools >/dev/null 2>&1); then
        sudo apt-get update
        if ! (sudo apt-get install -y --force-yes $dev_tools); then
            echo "ERROR: can't install tools: ${dev_tools}"
            exit 1
        fi
    fi
}

# jenkins job debug variables
function init_build_option() {
    SKIP_BUILD=${SKIP_BUILD:-"false"}
    SKIP_CP_IMAGE=${SKIP_CP_IMAGE:-"false"}
}

# ensure workspace exist
function init_workspace() {
    WORKSPACE=${WORKSPACE:-/home/ts/jenkins/workspace/estuary-build}
    mkdir -p ${WORKSPACE}
}

# init sub dirs path
function init_env_params() {
    WORK_DIR=${WORKSPACE}/local
    CI_SCRIPTS_DIR=${WORK_DIR}/ci-scripts
    CODE_REFERENCE=${CODE_REFERENCE:-/estuary_reference}
}

function init_build_env() {
    LANG=C
    PATH=${CI_SCRIPTS_DIR}/build-scripts:$PATH

    CPU_NUM=$(cat /proc/cpuinfo | grep processor | wc -l)
    OPEN_ESTUARY_DIR=${WORK_DIR}/open-estuary
    BUILD_DIR=${OPEN_ESTUARY_DIR}/build
    ESTUARY_CFG_FILE=${OPEN_ESTUARY_DIR}/estuary/estuarycfg.json
}

function clean_build() {
    if [ x"$SKIP_BUILD" = x"true" ];then
        :
    else
        sudo rm -fr $BUILD_DIR
    fi
}

function init_input_params() {
    # project name
    TREE_NAME=${TREE_NAME:-"open-estuary"}

    # select a version
    VERSION=${VERSION:-""}

    # select borad
    SHELL_PLATFORM=${SHELL_PLATFORM:-"d05"}
    SHELL_DISTRO=${SHELL_DISTRO:-"Ubuntu"}
    ARCH_MAP=${ARCH_MAP:-"d05 arm64"}

    # test plan
    BOOT_PLAN=${BOOT_PLAN:-"BOOT_NFS"}
    APP_PLAN=${APP_PLAN:-"TEST"}

    # preinstall packages
    PACKAGES=${PACKAGES:-""}

    # all setup types
    SETUP_TYPE=${SETUP_TYPE:-""}
}

function parse_params() {
    pushd ${CI_SCRIPTS_DIR}/boot-app-scripts    # change current work directory
    : ${SHELL_PLATFORM:=`python parameter_parser.py -f config.yaml -s Build -k Platform`}
    : ${SHELL_DISTRO:=`python parameter_parser.py -f config.yaml -s Build -k Distro`}

    : ${BOOT_PLAN:=`python parameter_parser.py -f config.yaml -s Jenkins -k Boot`}
    : ${APP_PLAN:=`python parameter_parser.py -f config.yaml -s Jenkins -k App`}

    : ${LAVA_SERVER:=`python parameter_parser.py -f config.yaml -s LAVA -k lavaserver`}
    : ${LAVA_USER:=`python parameter_parser.py -f config.yaml -s LAVA -k lavauser`}
    : ${LAVA_STREAM:=`python parameter_parser.py -f config.yaml -s LAVA -k lavastream`}
    : ${LAVA_TOKEN:=`python parameter_parser.py -f config.yaml -s LAVA -k TOKEN`}

    : ${FTP_SERVER:=`python parameter_parser.py -f config.yaml -s Ftpinfo -k ftpserver`}
    : ${FTP_DIR:=`python parameter_parser.py -f config.yaml -s Ftpinfo -k FTP_DIR`}

    : ${ARCH_MAP:=`python parameter_parser.py -f config.yaml -s Arch`}

    popd    # restore current work directory
}

function save_to_properties() {
    cat << EOF > ${WORKSPACE}/env.properties
TREE_NAME=${TREE_NAME}
GIT_DESCRIBE=${GIT_DESCRIBE}
SHELL_PLATFORM=${SHELL_PLATFORM}
SHELL_DISTRO=${SHELL_DISTRO}
BOOT_PLAN=${BOOT_PLAN}
APP_PLAN=${APP_PLAN}
ARCH_MAP=${ARCH_MAP}
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
    mkdir -p bin;
    export PATH=${WORK_DIR}/bin:$PATH;
    if [ ! -e bin ]; then
        if which repo;then
            echo "skip download repo"
        else
            echo "download repo"
            wget -c http://download.open-estuary.org/AllDownloads/DownloadsEstuary/utils/repo -O bin/repo
            chmod a+x bin/repo;
        fi
    fi
    popd
}

function sync_code() {
    mkdir -p $OPEN_ESTUARY_DIR;

    pushd $OPEN_ESTUARY_DIR;    # enter OPEN_ESTUARY_DIR

    # sync and checkout files from repo
    #repo init
    if [ x"$SKIP_BUILD" = x"true" ];then
        echo "skip git reset and clean"
    else
        repo forall -c git reset --hard || true
        repo forall -c git clean -dxf || true
    fi

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

# master don't have arch/arm64/configs/estuary_defconfig file
function hotfix_download_estuary_defconfig() {
    cd $OPEN_ESTUARY_DIR/kernel/arch/arm64/configs
    wget https://raw.githubusercontent.com/open-estuary/kernel/v3.1/arch/arm64/configs/estuary_defconfig -o estuary_defconfig
    cd -
}

# config the estuarycfg.json , do the build
function do_build() {
    pushd $OPEN_ESTUARY_DIR;    # enter OPEN_ESTUARY_DIR

    BUILD_CFG_FILE=/tmp/estuarycfg.json
    cp $ESTUARY_CFG_FILE $BUILD_CFG_FILE

    # Set all platforms support to "no"
    sed -i -e '/platform/s/yes/no/' $BUILD_CFG_FILE

    # Make platforms supported to "yes"
    echo $SHELL_PLATFORM
    for PLATFORM in $SHELL_PLATFORM; do
        PLATFORM_U=${PLATFORM^^}
        sed -i -e "/$PLATFORM_U/s/no/yes/" $BUILD_CFG_FILE
    done

    # Set all distros support to "no"
    distros=(Ubuntu OpenSuse Fedora Debian CentOS Rancher OpenEmbedded)
    for ((i=0; i<${#distros[@]}; i++)); do
        sed -i -e "/${distros[$i]}/s/yes/no/" $BUILD_CFG_FILE
    done

    # Make distros supported to "yes"
    echo $SHELL_DISTRO
    for DISTRO in $SHELL_DISTRO; do
        sed -i -e "/$DISTRO/s/no/yes/" $BUILD_CFG_FILE
    done

    # Set all packages supported to yes
    echo $PACKAGES
    for package in $PACKAGES; do
        sed -i -e "/${package}/s/no/yes/" $BUILD_CFG_FILE
    done

    # Set all setup types supported to "no"
    echo $SETUP_TYPE
    for setuptype in $SETUP_TYPE;do
        sed -i -e "/${setuptype}/s/yes/no/" $BUILD_CFG_FILE
    done

    cat $BUILD_CFG_FILE

    if [ x"$SKIP_BUILD" = x"true" ];then
        echo "skip build"
    else
        # Execute build
        ./estuary/build.sh --file=$BUILD_CFG_FILE --builddir=$BUILD_DIR
        if [ $? -ne 0 ]; then
            echo "estuary build failed!"
            exit -1
        fi
    fi

    print_time "the end time of estuary build is "

    popd

}

# generate version number by git sha
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


function parse_arch_map(){
    read -a arch_map <<< $(echo $ARCH_MAP)
    declare -A -g arch
    for((i=0; i<${#arch_map[@]}; i++)); do
        if ((i%2==0)); then
            j=`expr $i+1`
            arch[${arch_map[$i]}]=${arch_map[$j]}
        fi
    done
}

# image dir tree:
# .
# `-- kernel-ci
#     `-- open-estuary
#         `-- uefi_b386a15_grub_daac831_kernel_6eade8c
#             |-- arm64
#             |   |-- Estuary.iso
#             |   |-- Image
#             |   |-- System.map
#             |   |-- Ubuntu_ARM64.tar.gz
#             |   |-- Ubuntu_ARM64.tar.gz.sum
#             |   |-- deploy-utils.tar.bz2
#             |   |-- gcc-linaro-aarch64-linux-gnu-4.9-2014.09_linux.tar.xz
#             |   |-- gcc-linaro-arm-linux-gnueabihf-4.9-2014.09_linux.tar.xz
#             |   |-- grubaa64.efi
#             |   |-- mini-rootfs.cpio.gz
#             |   `-- vmlinux
#             |-- d05-arm64
#             |   |-- binary
#             |   |   |-- Image_D05 -> ../../arm64/Image
#             |   |   |-- UEFI_D05.fd
#             |   |   |-- deploy-utils.tar.bz2 -> ../../arm64/deploy-utils.tar.bz2
#             |   |   |-- grub.cfg
#             |   |   |-- grubaa64.efi -> ../../arm64/grubaa64.efi
#             |   |   `-- mini-rootfs.cpio.gz -> ../../arm64/mini-rootfs.cpio.gz
#             |   |-- distro
#             |   |   |-- Ubuntu_ARM64.tar.gz -> ../../arm64/Ubuntu_ARM64.tar.gz
#             |   |   `-- Ubuntu_ARM64.tar.gz.sum -> ../../arm64/Ubuntu_ARM64.tar.gz.sum
#             |   `-- toolchain
#             |       `-- gcc-linaro-aarch64-linux-gnu-4.9-2014.09_linux.tar.xz -> ../../arm64/gcc-linaro-aarch64-linux-gnu-4.9-2014.09_linux.tar.xz
#             `-- timestamp.log
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
    for PLATFORM in $SHELL_PLATFORM; do
        echo $PLATFORM

        PLATFORM_L="$(echo $PLATFORM | tr '[:upper:]' '[:lower:]')"
        PLATFORM_U="$(echo $PLATFORM | tr '[:lower:]' '[:upper:]')"
        PLATFORM_ARCH_DIR=$DES_DIR/${PLATFORM_L}-${arch[$PLATFORM_L]}
        [ -d $PLATFORM_ARCH_DIR ] && sudo rm -fr $PLATFORM_ARCH_DIR
        sudo mkdir -p ${PLATFORM_ARCH_DIR}/{binary,toolchain,distro}

        # copy toolchain files
        pushd $PLATFORM_ARCH_DIR/toolchain
        sudo ln -s ../../${arch[$PLATFORM_L]}/$TOOLCHAIN_FILE
        popd

        # copy binary files
        sudo find binary/$PLATFORM_U/ -type l -exec rm {} \;  || true # ensure remove symlinks
        sudo cp -rf binary/$PLATFORM_U/* $PLATFORM_ARCH_DIR/binary

        pushd $PLATFORM_ARCH_DIR/binary
        sudo ln -s ../../${arch[$PLATFORM_L]}/$KERNEL_IMG_FILE ${KERNEL_IMG_FILE}_${PLATFORM_U}
        sudo ln -s ../../${arch[$PLATFORM_L]}/$DEPLOY_UTILS_FILE
        sudo ln -s ../../${arch[$PLATFORM_L]}/$MINI_ROOTFS_FILE
        sudo ln -s ../../${arch[$PLATFORM_L]}/$GRUB_IMG_FILE

        # TODO : ln: failed to create symbolic link './grub.cfg': File exists
        sudo ln -s ../../${arch[$PLATFORM_L]}/$GRUB_CFG_FILE || true
        popd

        # copy distro files
        for DISTRO in $SHELL_DISTRO;do
            echo $DISTRO

            pushd ${CI_SCRIPTS_DIR}/boot-app-scripts
            distro_tar_name=`python parameter_parser.py -f config.yaml -s DISTRO -k $PLATFORM_U -v $DISTRO`
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
    popd  # leave OPEN_ESTUARY_DIR
}

function main() {
    prepare_tools

    init_build_option
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
    clean_build

    # hotfix_download_estuary_defconfig

    do_build
    get_version_info
    parse_arch_map
    if [ x"$SKIP_CP_IMAGE" = x"false" ];then
        cp_image
    fi
    save_to_properties
}

main
