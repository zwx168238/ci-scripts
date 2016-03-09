#!/usr/bin/python
import urllib2
import urlparse
import httplib
import re
import os
import shutil
import argparse
import ConfigParser

from lib import configuration

base_url = None
kernel = None
platform_list = []
legacy_platform_list = []

arch_distro = {'d01': ['Ubuntu_ARM32.tar.gz'],
               'd02': ['Fedora_ARM64.tar.gz', 'Ubuntu_ARM64.tar.gz',
                   'Debian_ARM64.tar.gz', 'OpenSuse_ARM64.tar.gz']}

panda_es = {'device_type': 'panda-es',
            'templates': ['generic-arm-dtb-kernel-ci-boot-template.json',
                          'generic-arm-dtb-kernel-ci-kselftest-template.json',
                          'generic-arm-dtb-kernel-ci-hackbench-template.json'],
            'defconfig_blacklist': ['arm-allmodconfig'],
            'kernel_blacklist': [],
            'nfs_blacklist': [],
            'lpae': False,
            'fastboot': False}

panda = {'device_type': 'panda',
         'templates': ['generic-arm-dtb-kernel-ci-boot-template.json',
                       'generic-arm-dtb-kernel-ci-kselftest-template.json',
                       'generic-arm-dtb-kernel-ci-hackbench-template.json'],
         'defconfig_blacklist': ['arm-allmodconfig'],
         'kernel_blacklist': [],
         'nfs_blacklist': [],
         'lpae': False,
         'fastboot': False}

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
       'templates': ['generic-arm-dtb-kernel-ci-boot-template.json',
                     'generic-arm-dtb-kernel-ci-kselftest-template.json'],
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
			      'd02-arm64-kernel-ci-weekly-template.json'],
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
                            'cyclictest.json',
                            'exec_latency.json',
                            'kselftest-net.json',
                            'netperf.json',
                            'smoke_basic_test.json',
                            'fio.json',
                            'lkp.json',
                            'network_tests_basic.json',
                            'sysbench.json'],}

snowball = {'device_type': 'snowball',
            'templates': ['generic-arm-dtb-kernel-ci-boot-template.json',
                          'generic-arm-dtb-kernel-ci-boot-nfs-template.json',
                          'generic-arm-dtb-kernel-ci-boot-nfs-mp-template.json',
                          'generic-arm-dtb-kernel-ci-ltp-mm-template.json',
                          'generic-arm-dtb-kernel-ci-ltp-syscalls-template.json',
                          'generic-arm-dtb-kernel-ci-kselftest-template.json',
                          'generic-arm-dtb-kernel-ci-hackbench-template.json'],
            'defconfig_blacklist': ['arm-allmodconfig'],
            'kernel_blacklist': [],
            'nfs_blacklist': [],
            'lpae': False,
            'fastboot': False}

x86 = {'device_type': 'x86',
       'templates': ['generic-x86-kernel-ci-boot-template.json',
                     'generic-x86-kernel-ci-kselftest-template.json',
                     'generic-x86-kernel-ci-hackbench-template.json'],
       'defconfig_blacklist': ['x86-i386_defconfig',
                               'x86-allnoconfig',
                               'x86-allmodconfig',
                               'x86-allmodconfig+CONFIG_OF=n',
                               'x86-tinyconfig',
                               'x86-kvm_guest.config'],
       'kernel_blacklist': [],
       'nfs_blacklist': [],
       'lpae': False,
       'fastboot': False}

x86_atom330 = {'device_type': 'x86-atom330',
                         'templates': ['generic-x86-kernel-ci-boot-template.json',
                                       'generic-x86-kernel-ci-kselftest-template.json',
                                       'generic-x86-kernel-ci-hackbench-template.json'],
                         'defconfig_blacklist': ['x86-i386_defconfig',
                                                 'x86-allnoconfig',
                                                 'x86-allmodconfig',
                                                 'x86-allmodconfig+CONFIG_OF=n',
                                                 'x86-tinyconfig',
                                                 'x86-kvm_guest.config'],
                         'kernel_blacklist': [],
                         'nfs_blacklist': [],
                         'lpae': False,
                         'fastboot': False}

x86_kvm = {'device_type': 'kvm',
           'templates': ['generic-x86-kernel-ci-boot-template.json',
                         'generic-x86-kernel-ci-kselftest-template.json',
                         'generic-x86-kernel-ci-hackbench-template.json'],
           'defconfig_blacklist': ['x86-i386_defconfig',
                                   'x86-allnoconfig',
                                   'x86-allmodconfig',
                                   'x86-allmodconfig+CONFIG_OF=n',
                                   'x86-tinyconfig',
                                   'x86-kvm_guest.config'],
           'kernel_blacklist': ['v3.10',
                                'lsk-v3.10'],
           'nfs_blacklist': [],
           'lpae': False,
           'fastboot': False}

device_map = {'omap4-panda-es.dtb': [panda_es],
              'omap4-panda.dtb': [panda],
              'hip04-d01.dtb': [d01],
              'hip05-d02.dtb': [d02],
              'hisi-x5hd2-dkb.dtb': [hisi_x5hd2_dkb],
              'ste-snowball.dtb': [snowball],
              #'vexpress-v2p-ca15-tc1.dtb': [qemu_arm_cortex_a15],
              #'vexpress-v2p-ca15-tc1-legacy': [qemu_arm_cortex_a15_legacy],
              #'vexpress-v2p-ca15_a7.dtb': [qemu_arm_cortex_a15_a7],
              #'vexpress-v2p-ca9.dtb': [qemu_arm_cortex_a9],
              #'vexpress-v2p-ca9-legacy': [qemu_arm_cortex_a9_legacy],
              #'qemu-arm-legacy': [qemu_arm],
              #'qemu-aarch64-legacy': [qemu_aarch64],
              #'juno.dtb': [juno, juno_kvm],
              #'hi6220-hikey.dtb': [hi6220_hikey],
              'x86': [x86, x86_atom330],
              'x86-kvm': [x86_kvm]}

parse_re = re.compile('href="([^./"?][^"?]*)"')

def setup_job_dir(directory):
    print 'Setting up JSON output directory at: jobs/'
    if not os.path.exists(directory):
        os.makedirs(directory)
    #else:
    #    shutil.rmtree(directory)
    #    os.makedirs(directory)
    print 'Done setting up JSON output directory'

# add by wuyanjun  2016/3/9
distro_list = []
def get_nfs_url(distro_url, device_type):
    parse_re = re.compile('href="([^./"?][^"?]*)"')
    try:
        html = urllib2.urlopen(distro_url, timeout=30).read()
    except IOError, e:
        print 'error reading %s: %s' % (url, e)
        exit(1)
    if not distro_url.endswith('/'):
        distro_url += '/'
    files= parse_re.findall(html)
    dirs = []
    for name in files:
        if not name.endswith('/'):
            dirs += [name]
        if name.endswith('.tar.gz') and 'distro' in distro_url+name and device_type in distro_url+name:
            distro_list.append(distro_url+name)
        for direc in dirs:
            get_nfs_url(distro_url+direc, device_type)

def create_jobs(base_url, kernel, plans, platform_list, targets, priority, distro_url):
    print 'Creating JSON Job Files...'
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
    for platform in platform_list:
        platform_name = platform.split('/')[-1]
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
                    total_templates = [ x for x in device_templates]
                    for json in dummy_ssh['templates']:
                        total_templates.append(json)
                    for template in total_templates:
                        job_name = tree + '-' + kernel_version + '-' + defconfig[:100] + '-' + platform_name + '-' + device_type + '-' + plan
                        if template in dummy_ssh['templates']:
                            job_json = cwd + '/jobs/' + job_name + '-' + template
                        else:
                            job_json = cwd + '/jobs/' + job_name + '.json'
                        template_file = cwd + '/templates/' + plan + '/' + str(template)
                        if os.path.exists(template_file):
                            with open(job_json, 'wt') as fout:
                                with open(template_file, "rt") as fin:
                                    for line in fin:
                                        tmp = line.replace('{dtb_url}', platform)
                                        tmp = tmp.replace('{kernel_url}', kernel)
                                        # add by wuyanjun
                                        if 'boot' not in plan and 'BOOT' not in plan:
                                            tmp = tmp.replace('{device_type}', 'dummy_ssh'+'_'+device_type)
                                        else:
                                            tmp = tmp.replace('{device_type}', device_type)
                                        tmp = tmp.replace('{job_name}',\
                                                job_json.split("/")[-1].split(".json")[0])
                                        # end by wuyanjun
                                        tmp = tmp.replace('{image_type}', image_type)
                                        tmp = tmp.replace('{image_url}', image_url)
                                        modules_url = image_url + 'modules.tar.xz'
                                        dummy_modules_url = 'https://googledrive.com/host/0B9DbsE2BbZ7ufjdLMVVONThlbE1mR3N4TjdFTVJod2c4TXpRUDZjMmF0Ylp4Ukk5VG14Ync/images/modules/modules.tar.xz'
                                        if has_modules:
                                            # Check if the if the modules actually exist
                                            if not checked_modules:
                                                # We only need to check that the modules
                                                # exist once for each defconfig
                                                p = urlparse.urlparse(modules_url)
                                                conn = httplib.HTTPConnection(p.netloc)
                                                conn.request('HEAD', p.path)
                                                resp = conn.getresponse()
                                                if resp.status > 400:
                                                    has_modules = False
                                                    print "No modules found, using dummy modules"
                                                    modules_url = dummy_modules_url
                                                checked_modules = True
                                        else:
                                            modules_url = dummy_modules_url
                                        tmp = tmp.replace('{modules_url}', modules_url)
                                        tmp = tmp.replace('{tree}', tree)
                                        if platform_name.endswith('.dtb'):
                                            tmp = tmp.replace('{device_tree}', platform_name)
                                        tmp = tmp.replace('{kernel_version}', kernel_version)
                                        if 'BIG_ENDIAN' in defconfig and plan == 'boot-be':
                                            tmp = tmp.replace('{endian}', 'big')
                                        else:
                                            tmp = tmp.replace('{endian}', 'little')
                                        tmp = tmp.replace('{defconfig}', defconfig)
                                        tmp = tmp.replace('{fastboot}', str(fastboot).lower())
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
                            with open(job_json, 'rb') as temp:
                                whole_lines = temp.read()
                            if re.findall('nfs_url', whole_lines):
                                get_nfs_url(distro_url, device_type)
                                if len(distro_list):
                                    fill_nfs_url(job_json, distro_list, device_type)
                            print 'JSON Job created: jobs/%s' % job_json.split('/')[-1]

def fill_nfs_url(job_json, distro_list, device_type):
    select_distro = [ x for x in distro_list if x.split('/')[-1] in arch_distro[device_type]]
    for distro in distro_list:
        rootfs = re.findall("(.*?).tar.gz", distro.split('/')[-1])
        rootfs_name = rootfs[0]
        modified_file = job_json.split('.json')[0] + '-' + rootfs_name + '.json'
        with open(modified_file, 'wt') as fout:
            with open(job_json, "rt") as fin:
                for line in fin:
                    tmp = line.replace('{nfs_url}', distro)
                    fout.write(tmp)
            print 'JSON Job created: jobs/%s' % modified_file.split('/')[-1]
    if os.path.exists(job_json):
        os.remove(job_json)

def walk_url(url, distro_url, plans=None, arch=None, targets=None, priority=None):
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
            #if 'zImage' in name and 'arm' in url:
            if 'zImage' in name:
                kernel = url + name
                base_url = url
                # qemu-arm,legacy
                if 'arm-versatile_defconfig' in url:
                    legacy_platform_list.append(url + 'qemu-arm-legacy')
            #if 'Image' in name and 'arm64' in url:
            if 'Image' in name:
                kernel = url + name
                base_url = url
            if name.endswith('.dtb') and name in device_map:
                if base_url and base_url in url:
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
                # qemu-arm,legacy
                if 'arm-versatile_defconfig' in url:
                    legacy_platform_list.append(url + 'qemu-arm-legacy')
            if name.endswith('.dtb') and name in device_map:
                if base_url and base_url in url:
                    legacy_platform_list.append(url + name)
        elif arch == 'arm64':
            if 'Image' in name and 'arm64' in url:
                kernel = url + name
                base_url = url
            if name.endswith('.dtb') and name in device_map:
                if base_url and base_url in url:
                    platform_list.append(url + name)
        if 'distro' in name:
            distro_url = url + name
    if kernel is not None and base_url is not None:
        if platform_list:
            print 'Found artifacts at: %s' % base_url
            create_jobs(base_url, kernel, plans, platform_list, targets,
                        priority, distro_url)
            # Hack for subdirectories with arm64 dtbs
            if 'arm64' not in base_url:
                base_url = None
                kernel = None
            platform_list = []
        elif legacy_platform_list:
            print 'Found artifacts at: %s' % base_url
            create_jobs(base_url, kernel, plans, legacy_platform_list, targets,
                        priority, distro_url)
            legacy_platform_list = []

    for dir in dirs:
        walk_url(url + dir, distro_url, plans, arch, targets, priority)

def main(args):
    config = configuration.get_config(args)

    setup_job_dir(os.getcwd() + '/jobs')
    print 'Scanning %s for kernel information...' % config.get("url")
    walk_url(config.get("url"), config.get("url"), config.get("plans"), config.get("arch"), config.get("targets"), config.get("priority"))
    print 'Done scanning for kernel information'
    print 'Done creating JSON jobs'
    exit(0)

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument("url", help="url to build artifacts")
    parser.add_argument("--config", help="configuration for the LAVA server")
    parser.add_argument("--section", default="default", help="section in the LAVA config file")
    parser.add_argument("--plans", nargs='+', required=True, help="test plan to create jobs for")
    parser.add_argument("--arch", help="specific architecture to create jobs for")
    parser.add_argument("--targets", nargs='+', help="specific targets to create jobs for")
    parser.add_argument("--priority", choices=['high', 'medium', 'low', 'HIGH', 'MEDIUM', 'LOW'],
                        help="priority for LAVA jobs")
    args = vars(parser.parse_args())
    main(args)
