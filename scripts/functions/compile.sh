#!/bin/bash

export MFBENCH_FUNCTIONS_COMPILE=true

function mfbench_logfile ()
{
  base_name=$1
  last_logfile=$(\ls -1 $base_name.[0-9][0-9].log 2>/dev/null | tail -1)
  if [ "$last_logfile" == "" ]; then
    this_num="01"
  else
    this_num=$(echo $last_logfile | cut -d "." -f2 | perl -ne 'printf "%02d", int($_)+1;')
  fi
  echo "$base_name.$this_num.log"
}

function mfbench_compile_1_threads ()
{
  gmk_threads=${MFBENCH_THREADS:-$(cat $MFBENCH_CONF/gmkpack-threads)}
  for ics_file in ics_*; do
    echo "Set GMK_THREADS=$gmk_threads for $PWD/$ics_file"
    perl -i -pe "
      s/GMK_THREADS=\d+/GMK_THREADS=$gmk_threads/go;
    " $ics_file
  done
}

function mfbench_compile_2_huboff ()
{
  for ics_file in $(\ls -1 ics_* 2>/dev/null | fgrep -v ics_packages); do
    echo "Switch off hub for $PWD/$ics_file"
    perl -i -pe "
      s/GMK_MAKE=ON/GMK_MAKE=OFF/go;
      s/GMK_INSTALL=ON/GMK_INSTALL=OFF/go;
    " $ics_file
  done
}

function mfbench_compile_3_mkild ()
{
  for ics_file in $(\ls -1 ics_* 2>/dev/null | fgrep -v ics_packages); do
    ild_file=${ics_file//ics_/ild_}
    echo "Creating $PWD/$ild_file"
    \cp $ics_file $ild_file
    perl -i -pe "
      s/ICS_RECURSIVE_UPDATE=yes/ICS_RECURSIVE_UPDATE=no/go;
      s/ICS_ICFMODE=full/ICS_ICFMODE=off/go;
      s/ICS_UPDLIBS=full/ICS_UPDLIBS=off/go;
    " $ild_file
  done
}
