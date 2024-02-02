#!/bin/bash

export MFBENCH_FUNCTIONS_COMPILE=true

function mfbench_compile_threads () {
  gmk_threads=$(cat $MFBENCH_CONF/gmkpack-threads)
  for ics_file in ics_*; do
    echo "Set GMK_THREADS=$gmk_threads for $PWD/$ics_file"
    perl -i -pe "
      s/GMK_THREADS=\d+/GMK_THREADS=$gmk_threads/go;
    " $ics_file
  done
}

function mfbench_compile_huboff () {
  for ics_file in $(\ls -1 ics_* 2>/dev/null | fgrep -v ics_packages); do
    echo "Switch off hub for $PWD/$ics_file"
    perl -i -pe "
      s/GMK_MAKE=ON/GMK_MAKE=OFF/go;
      s/GMK_INSTALL=ON/GMK_INSTALL=OFF/go;
    " $ics_file
  done
}
