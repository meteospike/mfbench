#!/bin/bash

echo "Setup for running method '$(basename $0 | cut -d "." -f2)'"

export INPART=1
export PERSISTENT=1
export PARALLEL=1
export LPARALLELMETHOD_VERBOSE=1
export LLSIMPLE_DGEMM=1

\cp $MFBENCH_PACKS/$CONFIG_PACK/lparallelmethod.txt.OPENACCSINGLECOLUMN lparallelmethod.txt

echo "Creating openacc binding"

$MFBENCH_SCRIPTS/tools/openacc-bind --nn $MASTER_NODES --nnp $MASTER_TASKS --np $MASTER_NPROC
cat openacc_bind.txt
