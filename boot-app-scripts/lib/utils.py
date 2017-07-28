#!/usr/bin/python
import os
import shutil
import urlparse
import xmlrpclib
import json
import yaml
import ssl


def write_file(file, name, directory):
    with open(os.path.join(directory, name), 'w') as f:
        f.write(file)


def write_json(name, directory, data):
    with open(os.path.join(directory, name), 'w') as f:
        json.dump(data, f, indent=4, sort_keys=True)

def load_json(json_file):
    with open(json_file, 'r') as f:
        return json.load(f)

def write_yaml(name, directory, data):
    with open(os.path.join(directory, name), 'w') as f:
        yaml.dump(data, f, indent=4)


def load_yaml(yaml_file):
    with open(yaml_file, 'r') as f:
        return yaml.load(f)

def mkdir(directory):
    if not ensure_dir(directory):
        shutil.rmtree(directory)
        os.makedirs(directory)

def get_value_by_key(list, key):
    for i in range(0, len(list)):
        line = list[i]
        if key in str(line.keys()):
            value = line.values()
            break
    return str(value).replace('[','').replace(']','').replace('\'','')

def ensure_dir(directory):
    if not os.path.exists(directory):
        os.makedirs(directory)
        return True
    else:
        return False


def in_bundle_attributes(bundle_atrributes, key):
    if key in bundle_atrributes:
        return True
    else:
        return False


def validate_input(username, token, server):
    url = urlparse.urlparse(server)
    if url.path.find('RPC2') == -1:
        print "LAVA Server URL must end with /RPC2"
        exit(1)
    return url.scheme + '://' + username + ':' + token + '@' + url.netloc + url.path


def connect(url):
    try:
        print "Connecting to Server..."
        if 'https' in url:
            context = hasattr(ssl, '_create_unverified_context') and ssl._create_unverified_context() or None
            connection = xmlrpclib.ServerProxy(url, transport=xmlrpclib.SafeTransport(use_datetime=True, context=context))
        else:
            connection = xmlrpclib.ServerProxy(url)

        print "Connection Successful!"
        print "connect-to-server : pass"
        return connection
    except (xmlrpclib.ProtocolError, xmlrpclib.Fault, IOError) as e:
        print "CONNECTION ERROR!"
        print "Unable to connect to %s" % url
        print e
        print "connect-to-server : fail"
        exit(1)
