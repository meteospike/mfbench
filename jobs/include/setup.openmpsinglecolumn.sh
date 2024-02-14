#!/bin/bash

echo "Setup for running method '$(basename $0 | cut -d "." -f2)'"

unset LPARALLELMETHOD_VERBOSE

export INPART=1
export PERSISTENT=1
export PARALLEL=1
export LLSIMPLE_DGEMM=1

\cp $MFBENCH_PACKS/$CONFIG_PACK/lparallelmethod.txt.OPENMPSINGLECOLUMN lparallelmethod.txt
