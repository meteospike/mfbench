#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import sys
import os
import io
import re

if 'MFBENCH_ROOT' in os.environ:
    mfbroot = os.path.join(os.environ['MFBENCH_ROOT'], 'bin')
else:
    mfbroot = os.path.dirname(os.path.realpath(sys.argv[0]))

with io.open(os.path.join(mfbroot, 'mfbench.sh'), 'r') as fd:
    doclines = [ [s.strip() for s in l.split(':')[1:4]] for l in fd.readlines() if re.match('\s*#:\w+:', l) ]

for section in sys.argv[1:]:
    print('--', section.upper(), '-' * (76-len(section)))
    for this_doc in sorted([l for l in doclines if l[0] == section]):
        print(' + {0:24s} : {1:s}'.format(this_doc[1], this_doc[2]))
