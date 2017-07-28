#!/usr/bin/python
import urllib2
import urlparse
import httplib
import re
import os
import shutil
import argparse
import subprocess
import ConfigParser

from lib import configuration
import parameter_parser

base_url = None
kernel = None
platform_list = []
legacy_platform_list = []

hisi_x5hd2_dkb = {'device_type': 'hi3716cv200',
                  'templates': ['generic-arm-dtb-kernel-ci-boot-template.json',
                                'generic-arm-dtb-kernel-ci-boot-nfs-template.json',
                                'generic-arm-dtb-kernel-ci-boot-nfs-mp-template.json',
                                'generic-arm-dtb-kernel-ci-ltp-mm-template.json',
                                'generic-arm-dtb-kernel-ci-ltp-syscalls-template.json',
                                'generic-arm-dtb-kernel-ci-kselftest-template.json'],
                  'defconfig_blacklist': ['arm-allmodconfig'],
                  'kernel_blacklist': [],
                  'nfs_blacklist': ['v3.',
                                    'lsk-v3.'],
                  'lpae': False,
                  'fastboot': False}

d01 = {'device_type': 'd01',
       'templates': ['d01-arm-dtb-kernel-ci-boot-template.json'],
       'defconfig_blacklist': ['arm-allmodconfig',
                               'arm-multi_v7_defconfig+linaro-base+distribution'],
       'kernel_blacklist': [],
       'nfs_blacklist': [],
       'lpae': True,
       'fastboot': False}

d02 = {'device_type': 'd02',
    'templates': ['d02-arm64-kernel-ci-boot-template.json',
                              'd02-arm64-kernel-ci-boot-sata-template.json',
                              'd02-arm64-kernel-ci-boot-nfs-template.json',
                              'd02-arm64-kernel-ci-boot-esl-template.json',
                              'd02-arm64-kernel-ci-boot-pxe-template.json',
                              'd02-arm64-kernel-ci-boot-norflash-template.json',
                              'd02-arm64-kernel-ci-weekly-template.json'],
    'defconfig_blacklist': ['arm64-allnoconfig',
                            'arm64-allmodconfig'],
                            'kernel_blacklist': [],
                            'nfs_blacklist': [],
                            'lpae': False,
                            'be': False,
                            'fastboot': False}

d03 = {'device_type': 'd03',
    'templates': ['d03-arm64-kernel-ci-boot-template.json',
                              'd03-arm64-kernel-ci-boot-sata-template.json',
                              'd03-arm64-kernel-ci-boot-nfs-template.json',
                              'd03-arm64-kernel-ci-boot-pxe-template.json',
                              'd03-arm64-kernel-ci-weekly-template.json'],
    'defconfig_blacklist': ['arm64-allnoconfig',
                            'arm64-allmodconfig'],
                            'kernel_blacklist': [],
                            'nfs_blacklist': [],
                            'lpae': False,
                            'be': False,
                            'fastboot': False}
d05 = {'device_type': 'd05',
    'templates': ['d05-arm64-kernel-ci-boot-template.json',
                              'd05-arm64-kernel-ci-boot-sata-template.json',
                              'd05-arm64-kernel-ci-boot-nfs-template.yaml',
                              'd05-arm64-kernel-ci-boot-pxe-template.json',
                              'd05-arm64-kernel-ci-weekly-template.json'],
    'defconfig_blacklist': ['arm64-allnoconfig',
                            'arm64-allmodconfig'],
                            'kernel_blacklist': [],
                            'nfs_blacklist': [],
                            'lpae': False,
                            'be': False,
                            'fastboot': False}


hi6220_hikey = {'device_type': 'hi6220-hikey',
                'templates': ['generic-arm64-dtb-kernel-ci-boot-template.json',
                              'generic-arm64-dtb-kernel-ci-kselftest-template.json',
                              'generic-arm64-uboot-dtb-kernel-ci-hackbench-template.json'],
                'defconfig_blacklist': ['arm64-allnoconfig',
                                        'arm64-allmodconfig'],
               'kernel_blacklist': [],
               'nfs_blacklist': [],
               'lpae': False,
               'fastboot': False}

dummy_ssh = {'device_type': 'dummy_ssh',
             'templates': [ 'device_read_perf.json',
                            'iperf_client.json',
                            'ltp.json',
                            'perf.json',
                            'cyclictest-basic.json',
                            'exec_latency.json',
                            'kselftest-net.json',
                            'netperf.json',
                            'fio.json',
                            'lkp.json',
                            'docker.json',
                            'ftp.json',
                            'lxc.json',
                            'mysql.json',
                            'smoke_basic_test.json',
                            'smoke.json',
                            'qemu.json',
                            #'network_tests_basic.json',
                            'sysbench.json'],}

device_map = {'hip04-d01.dtb': [d01],
              'hip05-d02.dtb': [d02],
              'D03': [d03],
              'D05': [d05],
              'hisi-x5hd2-dkb.dtb': [hisi_x5hd2_dkb],
              #'qemu-arm-legacy': [qemu_arm],
              #'qemu-aarch64-legacy': [qemu_aarch64],
              #'juno.dtb': [juno, juno_kvm],
              #'hi6220-hikey.dtb': [hi6220_hikey],
              }

parse_re = re.compile('href="([^./"?][^"?]*)"')

def setup_job_dir(directory):
    print 'Setting up YAML output directory at: jobs/'
    if not os.path.exists(directory):
        os.makedirs(directory)
    #else:
    #    shutil.rmtree(directory)
    #    os.makedirs(directory)
    print 'Done setting up YAML output directory'

# add by wuyanjun  2016/3/9
distro_list = []
def get_nfs_url(distro_url, device_type):
    parse_re = re.compile('href="([^./"?][^"?]*)"')
    if not distro_url.endswith('.tar.gz') or not distro_url.endswith('.gz'):
        try:
            html = urllib2.urlopen(distro_url, timeout=30).read()
        except IOError, e:
            print 'error reading %s: %s' % (url, e)
            exit(1)
        if not distro_url.endswith('/'):
            distro_url += '/'
    else:
        html = distro_url
    files= parse_re.findall(html)
    dirs = []
    for name in files:
        if not name.endswith('/'):
            dirs += [name]
        if name.endswith('.tar.gz') and 'distro' in distro_url+name and device_type in distro_url+name:
            distro_list.append(distro_url+name)
        for direc in dirs:
            get_nfs_url(distro_url+direc, device_type)

# add by wuyanjun 2016-06-25
def get_pubkey():
    key_loc = os.path.join(os.path.expandvars('$HOME'), '.ssh', 'id_rsa.pub')
   
    if os.path.exists(key_loc):
        pubkey = open(key_loc, 'r').read().rstrip()
    else:
        path = os.getcwd()
        subprocess.call(os.path.join(path, "generate_keys.sh"), shell=True)
        try:
            pubkey = open(key_loc, 'r').read().rstrip()
        except Exception:
            pubkey = ""
    return pubkey


def create_jobs(base_url, kernel, plans, platform_list, targets, priority,
                distro_url, distro="Ubuntu", sasFlag=False):
    print 'Creating YAML Job Files...'
    cwd = os.getcwd()
    url = urlparse.urlparse(kernel)
    build_info = url.path.split('/')
    image_url = base_url
    # TODO: define image_type dynamically
    image_type = 'kernel-ci'
    tree = build_info[1]
    kernel_version = build_info[2]
    defconfig = build_info[3]
    has_modules = True
    checked_modules = False

    pubkey = get_pubkey()
    for platform in platform_list:
        platform_name = platform.split('/')[-1].partition('_')[-1]
        for device in device_map[platform_name]:
            device_type = device['device_type']
            device_templates = device['templates']
            lpae = device['lpae']
            fastboot = device['fastboot']
            test_suite = None
            test_set = None
            test_desc = None
            test_type = None
            defconfigs = []
            for plan in plans:
                if 'boot' in plan or 'BOOT' in plan:
                    config = ConfigParser.ConfigParser()
                    try:
                        config.read(cwd + '/templates/' + plan + '/' + plan + '.ini')
                        test_suite = config.get(plan, 'suite')
                        test_set = config.get(plan, 'set')
                        test_desc = config.get(plan, 'description')
                        test_type = config.get(plan, 'type')
                        defconfigs = config.get(plan, 'defconfigs').split(',')
                    except:
                        print "Unable to load test configuration"
                        exit(1)
                if 'BIG_ENDIAN' in defconfig and plan != 'boot-be':
                    print 'BIG_ENDIAN is not supported on %s. Skipping JSON creation' % device_type
                elif 'LPAE' in defconfig and not lpae:
                    print 'LPAE is not supported on %s. Skipping JSON creation' % device_type
                elif defconfig in device['defconfig_blacklist']:
                    print '%s has been blacklisted. Skipping JSON creation' % defconfig
                elif any([x for x in device['kernel_blacklist'] if x in kernel_version]):
                    print '%s has been blacklisted. Skipping JSON creation' % kernel_version
                elif any([x for x in device['nfs_blacklist'] if x in kernel_version]) \
                        and plan in ['boot-nfs', 'boot-nfs-mp']:
                    print '%s has been blacklisted. Skipping JSON creation' % kernel_version
                elif 'be_blacklist' in device \
                        and any([x for x in device['be_blacklist'] if x in kernel_version]) \
                        and plan in ['boot-be']:
                    print '%s has been blacklisted. Skipping JSON creation' % kernel_version
                elif targets is not None and device_type not in targets:
                    print '%s device type has been omitted. Skipping JSON creation.' % device_type
                #elif not any([x for x in defconfigs if x == defconfig]) and plan != 'boot':
                #    print '%s has been omitted from the %s test plan. Skipping JSON creation.' % (defconfig, plan)
                else:
                    # add by wuyanjun in 2016/5/28
                    # add the profile of test cases, so only UT test case can be
                    # executed or ST can be executed.
                    for json in dummy_ssh['templates']:
                        device_templates.append(json)

                    total_templates = []
                    config_plan = ConfigParser.ConfigParser()
                    config_plan.read(cwd + '/templates/' + plan + '/' + plan + '.ini')
                    if test_kind != "BOTH":
                        single_templates = []
                        both_templates = []
                        try:
                            single_templates = [ x for x in device_templates if \
                                    x.split(".json")[0] in \
                                    config_plan.get("TEST_KIND", test_kind).split(",")]
                        except:
                            print "There is no %s test cases" % test_kind
                        try:
                            both_templates = [ x for x in device_templates if \
                                    x.split(".json")[0] in \
                                    config_plan.get("TEST_KIND", 'BOTH').split(",")]
                        except:
                            print "There is no UT and ST test cases"
                        total_templates = list(set(single_templates).union(set(both_templates)))
                    else:
                        # may be need to improve here because of all test cases will be executed
                        total_templates = [x for x in device_templates] 
                    # may need to change
                    get_nfs_url(distro_url, device_type)
                    for template in total_templates:
                        job_name = tree + '-' + kernel_version + '-' + defconfig[:100] + \
                                '-' + platform_name + '-' + device_type + '-' + plan
                        if template in dummy_ssh['templates']:
                            job_json = cwd + '/jobs/' + job_name + '-' + template
                        else:
                            job_json = cwd + '/jobs/' + job_name + '.yaml'
                        template_file = cwd + '/templates/' + plan + '/' + str(template)
                        if os.path.exists(template_file):
                            with open(job_json, 'wt') as fout:
                                with open(template_file, "rt") as fin:
                                    for line in fin:
                                        tmp = line.replace('{dtb_url}', platform)
                                        tmp = tmp.replace('{kernel_url}', kernel)
                                        # add by wuyanjun
                                        # if the jobs are not the boot jobs of LAVA, try to use the 
                                        # dummy_ssh as the board device, or use the ${board_type} itself.
                                        if 'boot' not in plan and 'BOOT' not in plan:
                                            tmp = tmp.replace('{device_type}', 'dummy_ssh'+'_'+device_type)
                                        else:
                                            tmp = tmp.replace('{device_type}', device_type)
                                        tmp = tmp.replace('{job_name}',\
                                                job_json.split("/")[-1].split(".yaml")[0])
                                        if sasFlag:
                                            tmp = tmp.replace('{distro}', distro)
                                        # end by wuyanjun
                                        tmp = tmp.replace('{image_type}', image_type)
                                        tmp = tmp.replace('{image_url}', image_url)
                                        tmp = tmp.replace('{tree}', tree)
                                        if platform_name.endswith('.dtb'):
                                            tmp = tmp.replace('{device_tree}', platform_name)
                                        tmp = tmp.replace('{kernel_version}', kernel_version)
                                        if 'BIG_ENDIAN' in defconfig and plan == 'boot-be':
                                            tmp = tmp.replace('{endian}', 'big')
                                        else:
                                            tmp = tmp.replace('{endian}', 'little')
                                        # add by wuyanjun in 2016-06-25
                                        if pubkey:
                                            tmp = tmp.replace('{lava_worker_pubkey}', pubkey)

                                        tmp = tmp.replace('{defconfig}', defconfig)
                                        tmp = tmp.replace('{fastboot}', str(fastboot).lower())
                                        tmp = tmp.replace('{distro_name}', distro)
                                        # add by zhaoshijie, lava doesn't support centos in its source code,cheat it
                                        if 'boot' in plan or 'BOOT' in plan:
                                            tmp = tmp.replace('{target_type}', 'ubuntu')
                                        else:
                                            tmp = tmp.replace('{target_type}', str(distro).lower())
                                        tmp = tmp.replace('{device_type_upper}', str(device_type).upper())
                                        if plan:
                                            tmp = tmp.replace('{test_plan}', plan)
                                        if test_suite:
                                            tmp = tmp.replace('{test_suite}', test_suite)
                                        if test_set:
                                            tmp = tmp.replace('{test_set}', test_set)
                                        if test_desc:
                                            tmp = tmp.replace('{test_desc}', test_desc)
                                        if test_type:
                                            tmp = tmp.replace('{test_type}', test_type)
                                        if priority:
                                            tmp = tmp.replace('{priority}', priority.lower())
                                        else:
                                            tmp = tmp.replace('{priority}', 'high')
                                        fout.write(tmp)
                            # add by wuyanjun 2016/3/8
                            # to support filling all the nfsroot url in the json template
                            with open(job_json, 'rb') as temp:
                                whole_lines = temp.read()
                            if re.findall('nfs_url', whole_lines):
                                if len(distro_list):
                                    fill_nfs_url(job_json, distro_list, device_type)
                            else:
                                if re.findall('nfs_distro', whole_lines):
                                    rootfs_name = distro.lower()
                                    modified_file = job_json.split('.yaml')[0] + '-' + rootfs_name + '.yaml'
                                    with open(modified_file, 'wt') as fout:
                                        with open(job_json, "rt") as fin:
                                            for line in fin:
                                                tmp = line
                                                if re.search('{nfs_url}', tmp):
                                                    tmp = line.replace('{nfs_url}', distro)
                                                if re.search('{nfs_distro}', tmp):
                                                    tmp = line.replace('{nfs_distro}', rootfs_name)
                                                fout.write(tmp)
                                    if os.path.exists(job_json):
                                        os.remove(job_json)

                            # add by wuyanjun 2016/5/12
                            # to support showing the distro name in the process of the SAS boot
                            if sasFlag:
                                new_name = job_json.split(".yaml")[0] + '-' + distro + '.yaml'
                                os.rename(job_json, new_name)
                                job_json = new_name
                            print 'YAML Job created: jobs/%s' % job_json.split('/')[-1]

# to fill the {nfs_url} instead of ${rootnfs_address_url}
def fill_nfs_url(job_json, distro_list, device_type):
    for distro in distro_list:
        rootfs = re.findall("(.*?).tar.gz", distro.split('/')[-1])
        rootfs_name = rootfs[0].split('_')[0].lower()
        modified_file = job_json.split('.yaml')[0] + '-' + rootfs_name + '.yaml'
        with open(modified_file, 'wt') as fout:
            with open(job_json, "rt") as fin:
                for line in fin:
                    tmp = line
                    if re.search('{nfs_url}', tmp):
                        tmp = line.replace('{nfs_url}', distro)
                    if re.search('{nfs_distro}', tmp):
                        tmp = line.replace('{nfs_distro}', rootfs_name)
                    fout.write(tmp)
            #print 'JSON Job created: jobs/%s' % modified_file.split('/')[-1]
    if os.path.exists(job_json):
        os.remove(job_json)

def walk_url(url, distro_url, plans=None, arch=None, targets=None,
            priority=None, distro="Ubuntu", SasFlag=False):
    global base_url
    global kernel
    global platform_list
    global legacy_platform_list

    try:
        html = urllib2.urlopen(url, timeout=30).read()
    except IOError, e:
        print 'error fetching %s: %s' % (url, e)
        exit(1)
    if not url.endswith('/'):
        url += '/'
    files = parse_re.findall(html)
    dirs = []
    for name in files:
        if name.endswith('/'):
            dirs += [name]
        if arch is None:
            if 'bzImage' in name and 'x86' in url:
                kernel = url + name
                base_url = url
                platform_list.append(url + 'x86')
                platform_list.append(url + 'x86-kvm')
            if 'zImage' in name and 'arm' in url:
                kernel = url + name
                base_url = url
            if 'Image' in name and 'arm64' in url:
                kernel = url + name
                base_url = url
            if name.endswith('.dtb') and name in device_map:
                if (base_url and base_url in url) or (base_url is None):
                    platform_list.append(url + name)
        elif arch == 'x86':
            if 'bzImage' in name and 'x86' in url:
                kernel = url + name
                base_url = url
                platform_list.append(url + 'x86')
                platform_list.append(url + 'x86-kvm')
        elif arch == 'arm':
            if 'zImage' in name and 'arm' in url:
                kernel = url + name
                base_url = url
            if name.endswith('.dtb') and name in device_map:
                if (base_url and base_url in url) or (base_url is None):
                    legacy_platform_list.append(url + name)
        elif arch == 'arm64':
            if 'Image' in name and 'arm64' in url:
                kernel = url + name
                base_url = url
            if name.startswith('Image') and name.partition('_')[2] in device_map:
                platform_list.append(url + name)
        if 'distro' in name:
            distro_url = url + name
    if kernel is not None and base_url is not None:
        if platform_list:
            print 'Found artifacts at: %s' % base_url
            create_jobs(base_url, kernel, plans, platform_list, targets,
                        priority, distro_url, distro, SasFlag)
            # Hack for subdirectories with arm64 dtbs
            if 'arm64' not in base_url:
                base_url = None
                kernel = None
            platform_list = []
        elif legacy_platform_list:
            print 'Found artifacts at: %s' % base_url
            create_jobs(base_url, kernel, plans, legacy_platform_list, targets,
                        priority, distro_url, distro, SasFlag)
            legacy_platform_list = []

    for dir in dirs:
        walk_url(url + dir, distro_url, plans, arch, targets, priority,\
                distro, SasFlag)

def main(args):
    global test_kind
    config = configuration.get_config(args)

    setup_job_dir(os.getcwd() + '/jobs')
    print 'Scanning %s for kernel information...' % config.get("url")
    distro = config.get("distro")
    if distro is None:
        distro = "Ubuntu"
    test_kind = config.get("testClassify")
    if test_kind is None:
        test_kind = "BOTH"
    walk_url(config.get("url"), config.get("url"), config.get("plans"),
            config.get("arch"), config.get("targets"), config.get("priority"),
            distro, config.get("SasFlag"))
    print 'Done scanning for kernel information'
    print 'Done creating YAML jobs'
    exit(0)

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument("url", help="url to build artifacts")
    parser.add_argument("--config", help="configuration for the LAVA server")
    parser.add_argument("--section", default="default", help="section in the\
            LAVA config file")
    parser.add_argument("--plans", nargs='+', required=True, help="test plan\
            to create jobs for")
    parser.add_argument("--arch", help="specific the architecture to create jobs\
            for")
    parser.add_argument("--targets", nargs='+', help="specific targets to create\
            jobs for")
    parser.add_argument("--priority", choices=['high', 'medium', 'low', 'HIGH',\
            'MEDIUM', 'LOW'],
                        help="priority for LAVA jobs")
    parser.add_argument("--distro", choices=['Ubuntu', 'OpenSuse', 'Debian', \
            'Fedora', 'CentOS'],
                        help="distro for sata deploying")
    # the SasFlag is used to flag if the lava job will use the Distro in the job name
    # when there is not {nfs_url} in the job definition
    parser.add_argument('--SasFlag', action='store_true')
    # BOTH means the case are both UT and ST
    parser.add_argument('--testClassify', help="the argument to distinguish \
            which tests run", choices=['UT', "ST", "BOTH"])
    args = vars(parser.parse_args())
    main(args)
