#!/usr/bin/env python
# -*- coding: utf-8 -*-
#                      
#    E-mail    :    wu.wu@hisilicon.com 
#    Data      :    2016-03-02 11:44:33
#    Desc      :

import yaml
from argparse import ArgumentParser

def read_value_of_key(filename, section, key):
    with open(filename, 'r') as fp:
        dictionary = yaml.load(fp)
    if section not in dictionary.keys():
        return ''
    else:
        if key not in dictionary[section].keys():
            return ''
        else:
            return dictionary[section][key]

def read_value_of_section(filename, section):
    with open(filename, 'r') as fp:
        dictionary = yaml.load(fp)
    if section not in dictionary.keys():
        return ''
    else:
        return dictionary[section]

if __name__ == "__main__":
    parser = ArgumentParser()
    parser.add_argument("-f", "--file", action="store",dest="filename", 
            help="which file to parser")
    parser.add_argument("-s", "--sections", action="store",
        dest="section", help="which section to select")
    parser.add_argument("-k", "--key", action="store", dest="key", 
            help="which key'value to be read")
    args = parser.parse_args()
    if args.filename and args.section and args.key:
        value = read_value_of_key(args.filename, args.section, args.key)
        if type(value)==list:
            for val in value: 
                print val
        else:
            print value
    if args.filename and args.section and not args.key:
        value = read_value_of_section(args.filename, args.section)
        if type(value)==dict:
            for val in value.keys():
                print val + " " + value[val]
        else:
            print value
