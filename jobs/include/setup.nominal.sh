#!/bin/bash

echo "Setup for running method '$(basename $0 | cut -d "." -f2)'"

export INPART=0
export PERSISTENT=0
export PARALLEL=0
unset LPARALLELMETHOD_VERBOSE
export LLSIMPLE_DGEMM=1
