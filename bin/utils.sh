#!/bin/bash

export MFBENCH_FUNCTIONS_UTILS=true


function check_private {
  if [ "$tempo_private" == "true" ]; then
    tempo_private=false
  else
    echo "Subcommand '$mfb' is internal only" >&2
    exit 1
  fi
}

function mandatory_var_raw {
  local this_var
  local actual_var
  for this_var in $*; do
    actual_var=MFBENCH_${this_var^^}
    if [ "${!actual_var}" == "" ]; then
      echo "Variable $actual_var is not set" >&2
      exit 1
    fi
  done
}

function mandatory_var_msg {
  local this_msg=$1
  shift
  local this_var
  local actual_var
  for this_var in $*; do
    actual_var=MFBENCH_${this_var^^}
    if [ "${!actual_var}" == "" ]; then
      echo "Variable $actual_var must be defined for $this_msg" >&2
      exit 1
    fi
  done
}

function mfbench_logfile {
  local this_num
  local base_name=$1
  local last_logfile=$(\ls -1 $base_name.[0-9][0-9].log 2>/dev/null | tail -1)
  if [ "$last_logfile" == "" ]; then
    this_num="01"
  else
    this_num=$(echo $last_logfile | cut -d "." -f2 | perl -ne 'printf "%02d", int($_)+1;')
  fi
  echo "$base_name.$this_num.log"
}

function mfbench_shortview {
  local this_item
  local this_info
  for this_item in pcunit arch opts pack; do
    this_info=$(fgrep "MFBENCH_${this_item^^}=" $MFBENCH_STORE/profile_$1/env.profile | cut -d "=" -f2)
    printf "[%s] " "$this_item:$this_info"
  done
}
