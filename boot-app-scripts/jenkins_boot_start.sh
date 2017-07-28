#!/bin/bash -ex
function init_build_option() {
    SKIP_LAVA_RUN=${SKIP_LAVA_RUN:-"false"}
}

function init_workspace() {
    WORKSPACE=${WORKSPACE:-/home/ubuntu/WORKSPACE}
    mkdir -p ${WORKSPACE}
}

function init_input_params() {
    GIT_DESCRIBE=${GIT_DESCRIBE:-"uefi_b386a15_grub_daac831_kernel_6eade8c"}

    TREE_NAME=${TREE_NAME:-"open-estuary"}
    SHELL_PLATFORM=${SHELL_PLATFORM:-"d05"}
    SHELL_DISTRO=${SHELL_DISTRO:-"Ubuntu"}
    ARCH_MAP=${ARCH_MAP:-"d05 arm64"}
    BOOT_PLAN=${BOOT_PLAN:-"BOOT_NFS BOOT_SAS"}
    APP_PLAN=${APP_PLAN:-"TEST"}
    USER=${USER:-"yangyang"}
    HOST=${HOST:-"192.168.67.123"}
    LAVA_SERVER=${LAVA_SERVER:-"http://172.17.0.10/RPC2"}
    LAVA_STREAM=${LAVA_STREAM:-"/anonymous/admin/"}
    LAVA_USER=${LAVA_USER:-"admin"}
    LAVA_TOKEN=${LAVA_TOKEN:-"0p9a29zs4rq15xyaaw9eza9sa1hsdb8axx4p9fankh6j0304wrla08w9n7s9qghn2m8bnofcolbrng0sy0zzef7awwt6hjnajhmnoq5aj0ufxm4mqt7629d3fskcnm75"}
    FTP_SERVER=${FTP_SERVER:-"http://192.168.1.108:8083"}
    FTP_DIR=${FTP_DIR:-"${WORK_DIR}/images/kernel-ci"}
    VERSION=${VERSION:-""}
}

function prepare_tool() {
    dev_tools="python-yaml python-keyring expect"

    if ! (dpkg-query -l $dev_tools >/dev/null 2>&1); then
        sudo apt-get update
        if ! (sudo apt-get install -y --force-yes $dev_tools); then
            return 1
        fi
    fi
}


function init_boot_env() {
    ESTUARY_DIR=estuary
    # TODO : need mount nfs first.
    BOOT_LOC=${BOOT_LOC:-/targetNFS/ubuntu_for_deployment/sys_setup/bin}
    BOOT_DIR=${BOOT_DIR:-/targetNFS/ubuntu_for_deployment/sys_setup/boot}
    ESTUARY_CI_DIR=estuary_ci_files
    JOBS_DIR=jobs
    RESULTS_DIR=results
}

function generate_jobs() {
    test_name=$1
    distro=$2
    harddisk_flag=$3
    pwd
    for PLAT in $SHELL_PLATFORM
    do
        board_arch=${dict[$PLAT]}
        if [ x"$distro" != x"" ]; then
            python estuary-ci-job-creator.py $FTP_SERVER/${TREE_NAME}/${GIT_DESCRIBE}/${PLAT}-${board_arch}/ --plans $test_name --distro $distro $harddisk_flag --arch ${board_arch}
        else
            python estuary-ci-job-creator.py $FTP_SERVER/${TREE_NAME}/${GIT_DESCRIBE}/${PLAT}-${board_arch}/ --plans $test_name --arch ${board_arch}
        fi

        if [ $? -ne 0 ]; then
            echo "create the boot jobs error! Aborting"
            return -1
        fi
    done
}

function run_and_report_jobs() {
    if [ x"$SKIP_LAVA_RUN" = x"false" ];then
        pushd ${JOBS_DIR}
        python ../estuary-job-runner.py --username $LAVA_USER --token $LAVA_TOKEN --server $LAVA_SERVER --stream $LAVA_STREAM --poll POLL
        popd

        if [ ! -f ${JOBS_DIR}/${RESULTS_DIR}/POLL ]; then
            echo "Running jobs error! Aborting"
            return -1
        fi

        python estuary-report.py --boot ${JOBS_DIR}/${RESULTS_DIR}/POLL --lab $LAVA_USER

        if [ ! -d ${RESULTS_DIR} ]; then
            echo "running jobs error! Aborting"
            return -1
        fi
    else
        echo "skip lava run and report"
    fi
}

function judge_pass_or_not() {
    FAIL_FLAG=$(grep -R 'FAIL' ./${JOBS_DIR}/${RESULTS_DIR}/POLL)
    if [ "$FAIL_FLAG"x != ""x ]; then
        echo "jobs fail"
        return -1
    fi

    PASS_FLAG=$(grep -R 'PASS' ./${JOBS_DIR}/${RESULTS_DIR}/POLL)
    if [ "$PASS_FLAG"x = ""x ]; then
        echo "jobs fail"
        return -1
    fi
}

function run_and_move_result() {
    test_name=$1
    dest_dir=$2

    ret_val=0
    run_and_report_jobs
    if [ $? -ne 0 ] ;then
        ret_val=-1
    fi

    judge_pass_or_not
    if [ $? -ne 0 ] ; then
        ret_val=-1
    fi

    [ -d ${JOBS_DIR} ] && mv ${JOBS_DIR} ${JOBS_DIR}_${test_name}
    [ -d ${RESULTS_DIR} ] && mv ${RESULTS_DIR} ${RESULTS_DIR}_${test_name}

    [ ! -d ${dest_dir} ] && mkdir -p ${dest_dir}
    [ -d ${JOBS_DIR}_${test_name} ] && mv ${JOBS_DIR}_${test_name} ${dest_dir}
    [ -d ${RESULTS_DIR}_${test_name} ] && mv ${RESULTS_DIR}_${test_name} ${dest_dir}

    if [ "$ret_val" -ne 0 ]; then
        return -1
    else
        return 0
    fi
}

function print_time() {
    echo -e "@@@@@@"$@ `date "+%Y-%m-%d %H:%M:%S"` "\n" >> $timefile
    #echo -e "\n"  >> $timefile
}

export

#######  Begining the tests ######

function init_timefile() {
    timefile=${WORKSPACE}/timestamp_boot.txt
    if [ -f ${timefile} ]; then
        rm -fr $timefile
    else
        touch $timefile
    fi
}

function init_summaryfile() {
    if [ -f ${WORKSPACE}/whole_summary.txt ]; then
        rm -rf ${WORKSPACE}/whole_summary.txt
    else
        touch ${WORKSPACE}/whole_summary.txt
    fi
}

function parse_arch_map() {
    read -a arch <<< $(echo $ARCH_MAP)
    declare -A -g dict
    for((i=0; i<${#arch[@]}; i++)); do
        if ((i%2==0)); then
            j=`expr $i+1`
            dict[${arch[$i]}]=${arch[$j]}
        fi
    done

    for key in "${!dict[@]}"; do echo "$key - ${dict[$key]}"; done
}

function clean_workspace() {
    set +e
    ##### Finish copying files to the lava-server machine #####

    rm -fr jobs*
    rm -fr results*

    [ -d $GIT_DESCRIBE ] && rm -fr $GIT_DESCRIBE
    set -e
}

function trigger_lava_build() {
    mkdir -p $GIT_DESCRIBE/${RESULTS_DIR}
    pushd ${WORKSPACE}/local/ci-scripts/boot-app-scripts
    for DISTRO in $SHELL_DISTRO; do
        if [ -d $DISTRO ];then
            rm -fr $DISTRO
        fi

        for boot_plan in $BOOT_PLAN; do
            rm -fr ${JOBS_DIR} ${RESULTS_DIR}

            # generate the boot jobs for all the targets
            if [ "$boot_plan" = "BOOT_SAS" ]  || [ "$boot_plan" = "BOOT_SATA" ]; then
                generate_jobs "boot" $DISTRO
                [ $? -ne 0 ] && continue

                # create the boot jobs for each target and run all these jobs
                cd ${JOBS_DIR}
                ls
                python ../create_boot_job.py --username $LAVA_USER --token $LAVA_TOKEN --server $LAVA_SERVER --stream $LAVA_STREAM
                if [ $? -ne 0 ]; then
                    echo "generate the jobs according the board devices error! Aborting"
                    continue
                fi

                cd ..
                run_and_move_result "boot" $DISTRO
                if [ $? -ne 0 ] ;then
                    python parser.py -d $DISTRO
                    if [ ! -d $GIT_DESCRIBE/${RESULTS_DIR}/${DISTRO} ];then
                        mv ${DISTRO} $GIT_DESCRIBE/${RESULTS_DIR}/ && continue
                    else
                        cp -fr ${DISTRO}/* $GIT_DESCRIBE/${RESULTS_DIR}/${DISTRO}/ && continue
                    fi
                fi

                print_time "the end time of deploy $DISTRO in HD through PXE is "

                #########################################
                ##### Entering the sata disk rootfs #####
                # generate the boot jobs for one target
                BOOT_FOR_TEST=BOOT_SAS
                rm -fr ${JOBS_DIR} ${RESULTS_DIR}

                generate_jobs ${BOOT_FOR_TEST} $DISTRO "--SasFlag"

                [ $? -ne 0 ] && continue
                cd ${JOBS_DIR}
                python ../create_boot_job.py --username $LAVA_USER --token $LAVA_TOKEN --server $LAVA_SERVER --stream $LAVA_STREAM
                if [ $? -ne 0 ]; then
                    echo "generate the jobs according the board devices error! Aborting"
                    continue
                fi

                cd ..
                if [ -d ${JOBS_DIR} ]; then
                    run_and_move_result ${BOOT_FOR_TEST} $DISTRO
                    if [ $? -ne 0 ] ;then
                        python parser.py -d $DISTRO
                        if [ ! -d $GIT_DESCRIBE/${RESULTS_DIR}/${DISTRO} ];then
                            mv ${DISTRO} $GIT_DESCRIBE/${RESULTS_DIR} && continue
                        else
                            cp -fr ${DISTRO}/* $GIT_DESCRIBE/${RESULTS_DIR}/${DISTRO}/ && continue
                        fi
                    fi
                fi

                print_time "the end time of boot $DISTRO from HD is "
                ##### End of entering the sata disk #####

                if [ x"$APP_PLAN" != x ] ; then
                    #####  modify the ip address according to the boot information
                    DEVICE_IP='device_ip_type.txt'
                    rm -fr /etc/lava-dispatcher/devices/$DEVICE_IP
                    cat $DISTRO/${RESULTS_DIR}_${BOOT_FOR_TEST}/${LAVA_USER}/${DEVICE_IP}
                    cp $DISTRO/${RESULTS_DIR}_${BOOT_FOR_TEST}/${LAVA_USER}/${DEVICE_IP} /etc/lava-dispatcher/devices
                    cp modify_conf_file.sh /etc/lava-dispatcher/devices
                    cd /etc/lava-dispatcher/devices; ./modify_conf_file.sh; cd -
                    sudo rm -fr $HOME/.ssh/known_hosts

                    if [ $? -ne 0 ]; then
                        echo "create ip and host mapping error! Aborting"
                        python parser.py  -d $DISTRO
                        if [ ! -d $GIT_DESCRIBE/${RESULTS_DIR}/${DISTRO} ];then
                            mv ${DISTRO} $GIT_DESCRIBE/${RESULTS_DIR} && continue
                        else
                            cp -fr ${DISTRO}/* $GIT_DESCRIBE/${RESULTS_DIR}/${DISTRO}/ && continue
                        fi
                    fi

                    rm -fr ${JOBS_DIR} ${RESULTS_DIR}
                    # generate the application jobs for the board_types
                    for app_plan in $APP_PLAN
                    do
                        [[ $app_plan =~ "BOOT" ]] && continue

                        generate_jobs $app_plan $DISTRO
                        if [ $? -ne 0 ] ;then
                            python parser.py -d $DISTRO
                            if [ ! -d $GIT_DESCRIBE/${RESULTS_DIR}/${DISTRO} ];then
                                mv ${DISTRO} $GIT_DESCRIBE/${RESULTS_DIR}/ && continue
                            else
                                cp -fr ${DISTRO}/* $GIT_DESCRIBE/${RESULTS_DIR}/${DISTRO}/ && continue
                            fi
                        fi
                    done

                    if [ -d ${JOBS_DIR} ]; then
                        run_and_report_jobs
                        test -d ${RESULTS_DIR}  && mv ${RESULTS_DIR} ${RESULTS_DIR}_app
                        test -d ${JOBS_DIR}  && mv ${JOBS_DIR} ${JOBS_DIR}_app
                        [ ! -d $DISTRO ] && mkdir -p $DISTRO
                        test -d ${JOBS_DIR}_app && mv ${JOBS_DIR}_app $DISTRO
                        test -d ${RESULTS_DIR}_app && mv ${RESULTS_DIR}_app $DISTRO

                        if [ $? -ne 0 ] ;then
                            python parser.py -d $DISTRO
                            if [ ! -d $GIT_DESCRIBE/${RESULTS_DIR}/${DISTRO} ];then
                                mv ${DISTRO} $GIT_DESCRIBE/${RESULTS_DIR}/ && continue
                            else
                                cp -fr ${DISTRO}/* $GIT_DESCRIBE/${RESULTS_DIR}/${DISTRO}/ && continue
                            fi
                        fi

                        print_time "the end time of running app of $DISTRO is "
                    fi
                fi

            else
                print_time "the start time of $boot_plan is "
                rm -fr ${JOBS_DIR} ${RESULTS_DIR}

                generate_jobs $boot_plan $DISTRO
                [ $? -ne 0 ] && python parser.py -d $DISTRO && mv $DISTRO $GIT_DESCRIBE/${RESULTS_DIR} && continue

                if [ -d ${JOBS_DIR} ]; then
                    run_and_move_result $boot_plan $DISTRO
                    if [ $? -ne 0 ] ;then
                        python parser.py -d $DISTRO
                        if [ ! -d $GIT_DESCRIBE/${RESULTS_DIR}/${DISTRO} ];then
                            mv ${DISTRO} $GIT_DESCRIBE/${RESULTS_DIR} && continue
                        else
                            cp -fr ${DISTRO}/* $GIT_DESCRIBE/${RESULTS_DIR}/${DISTRO}/ && continue
                        fi
                    fi
                fi

                print_time "the end time of $boot_plan is "
            fi
        done
        python parser.py -d $DISTRO
        mv $DISTRO $GIT_DESCRIBE/${RESULTS_DIR}
    done
    popd
}

function collect_result() {
    # push the binary files to the ftpserver
    DES_DIR=$FTP_DIR/$TREE_NAME/$GIT_DESCRIBE/
    [ ! -d $DES_DIR ] && echo "Don't have the images and dtbs" && exit -1

    pushd $GIT_DESCRIBE
    python ../parser.py -s ${RESULTS_DIR}
    popd

    tar czf test_result.tar.gz $GIT_DESCRIBE/*
    cp test_result.tar.gz  ${WORKSPACE}

    WHOLE_SUM='whole_summary.txt'
    if [  -e  ${WORKSPACE}/${WHOLE_SUM} ]; then
        rm -rf  ${WORKSPACE}/${WHOLE_SUM}
    fi
    cp $GIT_DESCRIBE/${RESULTS_DIR}/${WHOLE_SUM} ${WORKSPACE}
    cp -rf $timefile ${WORKSPACE}


    #zip -r ${GIT_DESCRIBE}_results.zip $GIT_DESCRIBE/*
    cp -f $timefile $GIT_DESCRIBE

    if [ -d $DES_DIR/$GIT_DESCRIBE/results ];then
        sudo rm -fr $DES_DIR/$GIT_DESCRIBE/results
        sudo rm -fr $DES_DIR/$GIT_DESCRIBE/$timefile
    fi
    sudo cp -rf $GIT_DESCRIBE/* $DES_DIR
    [ $? -ne 0 ]&& exit -1

    popd    # restore current work directory

    cat ${WORKSPACE}/timestamp_boot.txt

    if [ x"$BUILD_STATUS" != x"Successful"  ]; then
        BUILD_RESULT=${BUILD_STATUS}
    else
        BUILD_RESULT=Failure
    fi
}

function init_env() {
    WORK_DIR=${WORKSPACE}/local
    CI_SCRIPTS_DIR=${WORKSPACE}/local/ci-scripts
}

function main() {
    init_workspace
    init_build_option

    init_env
    init_boot_env

    init_input_params

    prepare_tool

    init_timefile
    print_time "the begin time of boot test is "
    init_summaryfile

    ##### copy some files to the lava-server machine to support the boot process #####
    parse_arch_map
    clean_workspace
    print_time "the time of preparing all envireonment is "
    trigger_lava_build
    collect_result
}

main
