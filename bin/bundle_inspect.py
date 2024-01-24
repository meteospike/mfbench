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

parser.add_argument('--file', default='BUNDLE-DEFAULT')
parser.add_argument('--item', default=None)
parser.add_argument('--conf', action='store_true')
parser.add_argument('--list', action='store_true')
parser.add_argument('--flat', action='store_true')

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
else:
    for bdle_type in bdle_entries:
        if bdle_dict[bdle_type]:
            bdle_flat.extend(bdle_dict[bdle_type].keys())
        if opts.item:
            if bdle_dict[bdle_type] and opts.item in bdle_dict[bdle_type]:
                this_bdle = bdle_dict[bdle_type][opts.item]
                print(f'MFBENCH_INSTALL_NAME={opts.item}')
                print(f'MFBENCH_INSTALL_TYPE={bdle_type}')
                if this_bdle["version"]:
                    print(f'MFBENCH_INSTALL_VERSION={this_bdle["version"]}')
                else:
                    print('MFBENCH_INSTALL_VERSION=""')
                if 'git' in this_bdle:
                    print(f'MFBENCH_INSTALL_GIT={this_bdle["git"]}')
                else:
                    actual_source = opts.item + '-' + this_bdle['version'] + '.' + this_bdle['archive']
                    print(f'MFBENCH_INSTALL_SOURCE={actual_source}')
                if 'gmkpack' in this_bdle:
                    print('MFBENCH_INSTALL_GMKPACK=true')
                    print(f'MFBENCH_INSTALL_TARGET=$MFBENCH_THISPACK/{this_bdle["gmkpack"]}')
                else:
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

