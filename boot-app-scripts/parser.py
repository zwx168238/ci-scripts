#!/usr/bin/env python
# -*- coding: utf-8 -*-
#                      
#    E-mail    :    wu.wu@hisilicon.com 
#    Data      :    2016-03-11 14:26:46
#    Desc      :

# this file is just for the result parsing
# the input is files in the directory named ''
import string
import os
import subprocess
import fnmatch
import time
import re
import sys
import shutil
import argparse

job_map = {}

parser_result = 'parser_result'
board_type_pre = 'board_type_'
summary_post = '_summary.txt'
summary='summary'
board_pre = 'board#'
whole_summary_name = 'whole_summary.txt'
match_str = '[A-Z]+(_[A-Z]+)*'
match_str_short = '[A-Z]+_[A-Z]*'
ip_address = 'device_ip_type.txt'
boot_pre = 'boot#'

total_str = "Total number of test cases: "
fail_str = "Failed number of test cases: "
suc_str = "Success number of test cases: "

# write summary for the special kind of test cases in the D02/Ubuntu
def summary_for_kind(result_dir):
    for root, dirs, files in os.walk(result_dir):
        for filename in files:
            if ip_address == filename:
                os.remove(os.path.join(root, filename))
                continue
            if filename.endswith(whole_summary_name):
                continue
            if 'boot' in filename or 'BOOT' in filename:
                continue
            if 'summary' in filename:
                try:
                    test_case_name = re.search(match_str, filename).group(0)
                except Exception:
                    test_case_name_1 = re.findall(match_str_short, filename)
                    if test_case_name_1:
                        test_case_name = test_case_name[0]
                test_kind = test_case_name
                if test_kind:
                    board_type = filename.split(test_kind)[0][:-1]
                else:
                    board_type_all = filename.split(summary_post)
                    if board_type_all:
                        board_type = board_type_all[0]
                if test_kind and board_type:
                    board_class = os.path.join(parser_result, board_type_pre + board_type)
                    if not os.path.exists(parser_result):
                        os.mkdir(parser_result)
                    # create the directory for the special kind of board
                    if not os.path.exists(board_class):
                        os.makedirs(board_class)
                    # create the test for each kind test, each file with one file
                    test_kind_name = os.path.join(board_class, test_kind)
                    if os.path.exists(test_kind_name):
                        os.remove(test_kind_name)
                    fail_cases = []
                    total_num = 0
                    with open(test_kind_name, 'ab') as fd:
                        with open(os.path.join(root, filename), 'rb') as rfd:
                            contents = rfd.read()
                        fd.write(board_type + '_' + test_kind + '\n')
                        total_num = len(re.findall("job_id", contents))
                        fail_num = 0
                        for case in contents.split('\n\n'):
                            test_case = re.findall("=+\s*\n(.*)\s*\n=+", case, re.DOTALL)
                            job_id = re.findall("(job_id.*)", case)
                            if test_case and job_id:
                                testname = test_case[0]
                                fail_flag = re.findall('FAIL', case)
                                if fail_flag:
                                    fail_num += 1
                                    fail_cases.append(job_id[0] + '\n' + testname + '\t\t' + 'FAIL\n')
                        fd.write(total_str + str(total_num) + '\n')
                        fd.write(fail_str + str(fail_num) + '\n')
                        fd.write(suc_str + str(total_num - fail_num) + '\n')
                        if len(fail_cases):
                            fd.write("\n================Failed cases===============\n")
                        for i in range(0, len(fail_cases)):
                            fd.write(fail_cases[i])

def write_summary_for_app(result_dir):
    dic_app_cases = {}
    # write summary for app
    for root, dirs, files in os.walk(result_dir):
        for dirname in dirs:
            # board_type_
            if board_type_pre in dirname:
                board_type = dirname.split(board_type_pre)[-1]
                # board#d02
                board_summary_name = board_pre + board_type
                total_num_case = 0
                fail_num_case = 0
                suc_num_case = 0
                for root1, dirs, files in os.walk(root):
                    for filename in files:
                        summary_name = os.path.join(result_dir, board_summary_name)
                        if board_type not in os.path.join(root1, filename):
                            continue
                        with open(summary_name, 'ab') as fd:
                            with open(os.path.join(root1, filename), 'rb') as rfd:
                                lines = rfd.readlines()
                                fd.write("Test category: " + filename + '\n')
                                for i in range(0, len(lines)):
                                    try:
                                        if re.match(total_str, lines[i]):
                                            total_num_case += string.atoi(re.findall('(\d+)', lines[i])[0][0])
                                        elif re.match(fail_str, lines[i]):
                                            fail_num_case += string.atoi(re.findall('(\d+)', lines[i])[0][0])
                                        elif re.match(suc_str, lines[i]):
                                            suc_num_case += string.atoi(re.findall('(\d+)', lines[i])[0][0])
                                        else:
                                            if re.search('FAIL', lines[i]):
                                                job_id = re.search('job_id.*?(\d+)', lines[i-1]).group(1)
                                                fd.write('\t' + str(job_id) + '\t' + lines[i])
                                    except Exception:
                                        continue
                                fd.write("\ttotal: %s  fail: %s  suc: %s\n" %\
                                        (total_num_case, fail_num_case, suc_num_case))
                dic_app_cases[board_type] = [total_num_case, fail_num_case, suc_num_case]
    return dic_app_cases

def write_summary_for_boot(boot_dir, dic_app_case):
    # write summary for boot
    dic_boot_num = {}
    for root, dirs, files in os.walk(boot_dir):
        for filename in files:
            # for the boot of ramdisk
            if 'boot' in filename and not filename.startswith('boot'):
                continue
            if 'BOOT' in filename and not filename.startswith('boot'):
                with open(os.path.join(root, filename), 'rb') as rfd:
                    content = rfd.read()
                boot_name = ''
                if re.findall('Full Boot Report', content):
                    try:
                        boot_name = re.search(match_str, filename).group(0)
                    except Exception:
                        boot_name_1 = re.findall(match_str_short, filename)
                        if boot_name_1:
                            boot_name = boot_name_1[0]
                    if not boot_name:
                        continue
                    with open(os.path.join(root, filename), 'rb') as rfd:
                        lines = rfd.readlines()
                    flag = len(lines) - 1
                    for i in range(len(lines)):
                        if re.findall('Full Boot Report', lines[i]):
                            flag = i
                            break
                    total_num = 0
                    fail_num = 0
                    suc_num = 0
                    for i in range(flag+1, len(lines)):
                        try:
                            if len(lines[i]) <= 1:
                                continue
                            board_type = lines[i].split()[2].split('_')[0]
                            boot_result = lines[i].split()[-1]
                            job_id = lines[i].split()[0]
                            job_name = lines[i].split()[-2].split(":")[0]
                            boot_summary_name = boot_pre + 'summary'
                            dic_boot_num[board_type] = []
                            with open(os.path.join(boot_dir, boot_summary_name), 'ab') as fd:
                                if re.findall('FAIL', lines[i]):
                                    total_num += 1
                                    fail_num += 1
                                    fd.write('\t' + job_id + '\t' + board_type\
                                            + '\t' + boot_name + '\t' + job_name\
                                            + '\t' + 'FAIL\n')
                                else:
                                    total_num += 1
                                    suc_num += 1
                                    fd.write('\t' + job_id + '\t' + board_type\
                                            + '\t' + boot_name + '\t' + job_name\
                                            + '\t' + 'PASS\n')
                        except IndexError:
                            continue
                        dic_boot_num[board_type] = [total_num, fail_num, suc_num]
    return dic_boot_num

def sum_of_dic(dic1, dic2):
    dic_sum = {}
    for key in dic1.keys():
        if key in dic2.keys():
            if key not in dic_sum.keys():
                dic_sum[key] = [0, 0, 0]
            dic_sum[key][0] = dic1[key][0] + dic2[key][0]
            dic_sum[key][1] = dic1[key][1] + dic2[key][1]
            dic_sum[key][2] = dic1[key][2] + dic2[key][2]
        else:
            dic_sum[key] = dic1[key]
    for key in dic2.keys():
        if key not in dic1.keys():
            dic_sum[key] = dic2[key]
    return dic_sum

def summary_for_board(boot_dir, result_dir):
    dic_app_case = write_summary_for_app(result_dir)
    dic_boot_case = write_summary_for_boot(boot_dir, dic_app_case)
    dic_sum = sum_of_dic(dic_app_case, dic_boot_case)
    for board in dic_app_case.keys():
        board_summary_name = board_pre + board
        with open(os.path.join(result_dir, board_summary_name), 'ab') as fd:
            fd.write("\n" + total_str + str(dic_app_case[board][0]))
            fd.write("\n" + fail_str + str(dic_app_case[board][1]))
            fd.write("\n" + suc_str + str(dic_app_case[board][2]) + '\n')

def parser_all_files(result_dir):
    summary_path = os.path.join(result_dir, whole_summary_name)
    if os.path.exists(summary_path):
        os.remove(summary_path)
    # get kind classfication in each file
    true_parser_path = os.path.join(result_dir, parser_result)
    if os.path.exists(true_parser_path):
        shutil.rmtree(true_parser_path)
    if os.path.exists(parser_result):
        shutil.rmtree(parser_result)
    summary_for_kind(result_dir)
    # summary each file for each kind of board
    if os.path.exists(parser_result):
        summary_for_board(result_dir, parser_result)
        shutil.move(parser_result, result_dir)
    else:
        summary_for_board(result_dir, result_dir)

def print_dic(dic_app, wfp):
    if len(dic_app.keys()) <= 0:
        return
    for k, v in dic_app.iteritems():
        wfp.write("\nThe board is " + k + '\n')
        distro_keys = v.keys()             # opensuse, ubuntu and so on
        test_values = v.values()    # {'weekly_testing':{XXX}, 'network':{XXX}},{},
        total_test_case = []
        for test_value in test_values:
            tmp_test_kind = test_value.keys()  # 'weekly_testing', 'network', ...
            total_test_case = list(set(total_test_case).union(set(tmp_test_kind)))
        # print the title
        wfp.write('Distro\t')
        for i in range(0, len(total_test_case)):
            wfp.write(total_test_case[i]+'\t')
        wfp.write('sum\n')
        # print the distro and test case value
        for distro in distro_keys:
            total_fail = 0
            total_suc = 0
            wfp.write(distro + '\t')
            for test_classify in total_test_case:
                try:
                    fail_num = v[distro][test_classify]['fail']
                    suc_num = v[distro][test_classify]['suc']
                    total_fail += fail_num
                    total_suc += suc_num
                    wfp.write('F:' + str(fail_num) + ' P:' + str(suc_num) + '\t')
                except Exception:
                    wfp.write('F: 0 P: 0\t')
                    continue
            wfp.write('F:' + str(total_fail) + ' P:' + str(total_suc) + '\n')
    # end of the print

def summary_for_apps(summary_dir, wfp):
    total_num_app = 0
    fail_num_app = 0
    suc_num_app = 0
    wfp.write("\n" + "*"*20 + " APPLICATION SUMMARY START " + "*"*20 + '\n')
    dic_app = {}
    for root, dirs, files in os.walk(summary_dir):
        for filename in files:
            if re.match(board_pre, filename):
                flag = 0
                # get the board type
                board_type = filename.split(board_pre)[1]
                if board_type not in dic_app.keys():
                    dic_app[board_type] = {}
                whole_path = os.path.join(root, filename)
                # get the distro
                distro = _get_distro(whole_path)
                if distro == "":
                    break
                if distro not in dic_app[board_type].keys():
                    dic_app[board_type][distro]={}
                tmp_dic = dic_app[board_type][distro]
                with open(whole_path) as rfd:
                    contents = rfd.read()
                    blocks = contents.split("\n\n")
                    for block in blocks:
                        all_test_category = re.findall("Test category:\s+(.*)\n", block)
                        if all_test_category and block:
                            test_category = all_test_category[0]
                            values = re.findall(".+?\s(\d+)", block)
                            if len(values) == 3:
                                tmp_suc = int(values[2])
                                suc_num_app += tmp_suc
                                tmp_fail = int(values[1])
                                fail_num_app += tmp_fail
                                tmp_total = int(values[0])
                                if tmp_total != tmp_fail + tmp_suc:
                                    print "there is error when parsing result for %s %s %s" % (board_type, distro, test_category)
                                    break
                                total_num_app += tmp_total
                            if test_category not in tmp_dic.keys():
                                tmp_dic[test_category] = {'fail': tmp_fail, 'suc': tmp_suc}
    print_dic(dic_app, wfp)
    wfp.write("\n" + "*"*20 + " APPLICATION SUMMARY END " + "*"*20 + '\n')
    print dic_app
    return (total_num_app, fail_num_app, suc_num_app)

def summary_all_files(summary_dir):
    summary_file = os.path.join(summary_dir, whole_summary_name)
    if os.path.exists(summary_file):
        os.remove(summary_file)
    with open(summary_file, 'ab') as wfp:
        total_num = 0
        suc_num = 0
        fail_num = 0
        wfp.write("*"*20 + " BOOT SUMMARY START " + "*"*20 + '\n')
        for root, dirs, files in os.walk(summary_dir):
            for filename in files:
                if re.match(boot_pre + summary, filename):
                    with open(os.path.join(root, filename), 'rb') as rfb:
                        contents = rfb.read()
                        wfp.write(contents)
                        suc_num += len(re.findall('PASS', contents))
                        fail_num += len(re.findall('FAIL', contents))
        total_num = suc_num + fail_num
        wfp.write("\n" + total_str + str(total_num))
        wfp.write("\n" + fail_str + str(fail_num))
        wfp.write("\n" + suc_str + str(suc_num))
        wfp.write("\n" + "*"*20 + " BOOT SUMMARY END" + "*"*20 + '\n')

        (total_num_app, fail_num_app, suc_num_app) = \
                summary_for_apps(summary_dir, wfp)

        wfp.write('\n' + "*"*20 + " SUMMARY START " + "*"*20 + '\n')
        wfp.write(total_str + str(total_num + total_num_app))
        wfp.write('\n' + fail_str + str(fail_num + fail_num_app))
        wfp.write('\n' + suc_str + str(suc_num + suc_num_app))
        wfp.write('\n' + "*"*20 + " SUMMARY END " + "*"*20 + '\n')

def _get_distro(path):
    distro = ""
    if re.search("Ubuntu", path) or re.search("ubuntu", path):
        distro = "Ubuntu"
    elif re.search("OpenSuse", path) or re.search("opensuse", path):
        distro = "OpenSuse"
    elif re.search("CentOS", path) or re.search("centos", path):
        distro = "CentOS"
    elif re.search("Debian", path) or re.search("debian", path):
        distro = "Debian"
    else:
        if re.search("Fedora", path) or re.search("fedora", path):
            distro = "fedora"
    return distro

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument("-d", "--directory", action="store", dest="parse", help="which directory to parser for the test category")
    parser.add_argument("-s", "--summary", action="store", dest="summary", help="which directory to parser and get the summary result")
    args = parser.parse_args()
    if args.parse:
        result_dir = args.parse
        if result_dir:
            parser_all_files(result_dir)
    if args.summary:
        summary_dir = args.summary
        if summary_dir:
            summary_all_files(summary_dir)

