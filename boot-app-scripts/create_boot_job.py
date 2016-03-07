#!/usr/bin/env python
# -*- coding: utf-8 -*-
#                      
#    E-mail    :    wu.wu@hisilicon.com 
#    Data      :    2016-01-20 15:26:46
#    Desc      :

# Usage ./lava-job-runner.py <username> <token> <lava_server_url> [job_repo] [bundle_stream]

import os
import xmlrpclib
import json
import subprocess
import fnmatch
import time
import re
import argparse
import httplib

from lib import utils
from lib import configuration

job_map = {}

def create_jobs(connection, server, bundle_stream=None):
    
    types_devices_map = gather_devices_types_map(connection)
    
    for job in job_map:
        with open(job, 'rb') as stream:
            job_data = stream.read()
        job_info = json.loads(job_data)
        # Check if request device(s) are available
        if 'device_type' in job_info:
            device_type = job_info['device_type']
            if device_type in types_devices_map.keys():
                del job_info['device_type']
                for value in types_devices_map[device_type]:
                    job_info['target'] = value
                    job_name = job.split(".json")[0]+'-'+value+'.json'
                    json.dump(job_info, open(job_name, 'w'), sort_keys=True,
                            indent=4, separators=(',', ':'))
                os.remove(job)
            else:
                print "No device-type available on server, skipping..."
                print os.path.basename(job) + ' not valiable'

def load_jobs():
    top = os.getcwd()
    for root, dirnames, filenames in os.walk(top):
        for filename in fnmatch.filter(filenames, '*.json'):
            job_map[os.path.join(root, filename)] = None


def gather_devices_types_map(connection):
    device_types = connection.scheduler.all_device_types()
    devices = connection.scheduler.all_devices()

    mapping = {}
    for device in devices:
        if device[1] not in mapping.keys():
            mapping[device[1]] = []
            mapping[device[1]].append(device[0])
        else:
            mapping[device[1]].append(device[0])
    return mapping

def main(args):
    config = configuration.get_config(args)

    url = utils.validate_input(config.get("username"), config.get("token"), config.get("server"))
    connection = utils.connect(url)
    load_jobs()
    start_time = time.time()

    bundle_stream = None
    if config.get("stream"):
        bundle_stream = config.get("stream")

    create_jobs(connection, config.get("server"), bundle_stream=bundle_stream)

    exit(0)

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument("--username", help="username for the LAVA server")
    parser.add_argument("--token", help="token for LAVA server api")
    parser.add_argument("--server", help="server url for LAVA server")
    parser.add_argument("--stream", help="bundle stream for LAVA server")
    args = vars(parser.parse_args())
    main(args)
