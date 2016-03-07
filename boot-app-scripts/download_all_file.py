
# -*- coding: utf-8 -*-
#                      
#    E-mail    :    wu.wu@hisilicon.com 
#    Data      :    2016-03-02 17:26:17
#    Desc      :

import re
import sys
import getopt
import urllib2
from urllib2 import URLError
import logging
import subprocess

parse_re = re.compile('href="([^./"?][^"?]*)"')
def get_urlname(git_describe, job_tree, url, token):
    array = [url, job_tree, git_describe]
    urlname = '/'.join(array) 
    try:
        response = urllib2.urlopen(urlname, timeout=30).read()
    except URLError, e:
        logging.info("the url %s is not valid" % urlname)
        return ''
    else:
        return urlname
    
address_list = []
download_file = []
def walk(url):
    try: 
        html = urllib2.urlopen(url, timeout=30).read()
    except IOError, e:
        print "error reading %s: %s" % (url, e)
        exit(1)

    if not url.endswith('/'):
        url += '/'
    files = parse_re.findall(html)
    dirs = []
    for name in files:
        if name.endswith('/'):
            dirs += [name]
        if name.endswith('.dtb'):
            if url+name not in address_list:
                address_list.append(url + name)
            if name not in download_file:
                download_file.append(name)
        if 'mage' in name or 'cpio' in name:
            if url+name not in address_list:
                address_list.append(url + name)
            if name not in download_file:
                download_file.append(name)
        for direc in dirs:
            walk(url + direc)

def download(lists):
    for item in lists:
        ret = subprocess.call('wget %s' % item, shell=True,
                stdout=open('/dev/null', 'w'), stderr=subprocess.STDOUT)
        if ret==0:
            print '%s download success' % item
        else:
            print '%s download failed' % item
    
if __name__ == "__main__":
    try:
        opts, args = getopt.getopt(sys.argv[1:], "d:j:u:t")
    except getopt.GetoptError as err:
        print str(err)
        sys.exit(2)
    direc = ''
    job = ''
    url = "http://192.168.1.108:8083"
    token = "3eda8013-da37-42ea-b9a0-7a66badd1b68"
    for option, value in opts:
        if option == "-d":
            direc = value
        if option == "-j":
            job = value
        if option == "-u":
            url = value
        if option == "-t":
            token = value
    if not direc and not job:
        exit(-1)
    urlname = get_urlname(git_describe=direc, job_tree=job, url=url, token=token)
    #print urlname
    walk(urlname)
    #print address_list
    download(address_list)
    for filename in download_file:
        print filename
