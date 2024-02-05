#!/usr/bin/env python3
# -*- coding: utf-8 -*-


import os
import io
import sys
import argparse
import yaml


parser = argparse.ArgumentParser(
    prog = 'bundle_inspect',
    description = 'Inspect default or specified bundle file use to build mfbench'
)

parser.add_argument('--file', default='BUNDLE-SELECT.'+os.environ.get('MFBENCH_PROFILE', 'default'))
parser.add_argument('--item', default=None)
parser.add_argument('--conf', action='store_true')
parser.add_argument('--list', action='store_true')
parser.add_argument('--flat', action='store_true')
parser.add_argument('--type', default=None)

opts = parser.parse_args()

if os.environ['MFBENCH_CONF'] is None:
    sys.stderr.write('MFBENCH_CONF variable is not set\n')
    exit(1)

with io.open(os.path.join(os.environ['MFBENCH_CONF'], opts.file), 'r') as fbdl:
    bdle_dict = yaml.safe_load(fbdl)

bdle_entries = sorted(bdle_dict.keys())
bdle_flat = list()

if opts.list:
    print(' '.join(bdle_entries))
elif opts.type:
    if opts.type in bdle_dict:
        print(' '.join(sorted(bdle_dict[opts.type].keys())))
    else:
        sys.stderr.write(f"Type '{opts.type}' not in that bundle\n")
else:
    for bdle_type in bdle_entries:
        if bdle_dict[bdle_type]:
            bdle_flat.extend(bdle_dict[bdle_type].keys())
        if opts.item:
            if bdle_dict[bdle_type] and opts.item in bdle_dict[bdle_type]:
                if bdle_type == 'tools':
                    print('MFBENCH_INSTALL_MKARCH=no')
                else:
                    print('MFBENCH_INSTALL_MKARCH=yes')
                this_bdle = bdle_dict[bdle_type][opts.item]
                print(f'MFBENCH_INSTALL_NAME={opts.item}')
                print(f'MFBENCH_INSTALL_TYPE={bdle_type}')
                actual_threads  = this_bdle.get('threads', '4')
                print(f'MFBENCH_INSTALL_THREADS={actual_threads}')
                if this_bdle["version"]:
                    print(f'MFBENCH_INSTALL_VERSION="{this_bdle["version"]}"')
                else:
                    print('MFBENCH_INSTALL_VERSION=""')
                if 'git' in this_bdle:
                    actual_topdir  = this_bdle.get('topdir', opts.item)
                    print(f'MFBENCH_INSTALL_TOPDIR={actual_topdir}')
                    print(f'MFBENCH_INSTALL_GIT={this_bdle["git"]}')
                else:
                    actual_topdir  = this_bdle.get('topdir', opts.item + '-' + this_bdle['version'])
                    actual_archive = this_bdle.get('archive', 'tar.gz')
                    actual_source  = this_bdle.get('source', actual_topdir) + '.' + actual_archive
                    print(f'MFBENCH_INSTALL_TOPDIR={actual_topdir}')
                    print(f'MFBENCH_INSTALL_SOURCE={actual_source}')
                if 'gmkpack' in this_bdle:
                    print('MFBENCH_INSTALL_GMKPACK=yes')
                    print(f'MFBENCH_INSTALL_TARGET=$MFBENCH_ROOTPACK/$MFBENCH_PACK/{this_bdle["gmkpack"]}')
                else:
                    print('MFBENCH_INSTALL_GMKPACK=no')
                    if bdle_type.startswith('lib'):
                        print('MFBENCH_INSTALL_TARGET=$MFBENCH_INSTALL/$MFBENCH_ARCH')
                    else:
                        print(f'MFBENCH_INSTALL_TARGET=$MFBENCH_INSTALL/{bdle_type}')
        elif opts.conf:
            if bdle_dict[bdle_type]:
                bdle_items = ' '.join(sorted(bdle_dict[bdle_type].keys()))
            else:
                bdle_items = ''
            print(f'{bdle_type}:{bdle_items}')

if opts.flat:
    print(' '.join(sorted(bdle_flat)))

