#!/bin/bash

export MFBENCH_FUNCTIONS_DIRECTORIES=true

function mfbench_mkdir
{
  local dirkind="MFBENCH_${1^^}"
  local dirfull=${!dirkind}
  if [ ! -d "$dirfull" ]; then
    echo "Create $1 directory: $dirfull"
    mkdir -p $dirfull
  fi
}

function mfbench_mkdir_ln
{
  mfbench_mkdir $1
  if [ ! -e "$2/$1" ]; then
    local dirkind="MFBENCH_${1^^}"
    local dirfull=${!dirkind}
    echo "Link $dirfull -> $2/$1"
    \ln -s $dirfull $2/$1
  fi
}

function mfbench_renew_ln
{
  local mfb_name=$1
  local src_path=$2
  if [ ! -d $src_path ]; then
    echo "Source directory $src_path not found" >&2
    exit 1
  fi
  local top_name=$(fgrep "$mfb_name:" $MFBENCH_CONF/mfbench-optlink | cut -d ":" -f2)
  if [ "$top_name" == "" ]; then
    echo "Directory '$mfb_name' is not linkable" >&2
    exit 1
  fi
  local top_var="MFBENCH_${top_name^^}"
  local top_path=${!top_var}
  echo "Attach directory is $top_path"
  if [ -L $top_path/$mfb_name ]; then
    echo "Removing $top_path/$mfb_name"
    \rm -f $top_path/$mfb_name
  elif [ -d $top_path/$mfb_name ]; then
    \rmdir $top_path/$mfb_name 2>/dev/null
  fi
  echo "Link $src_path -> $mfb_name"
  \ln -s $src_path $top_path/$mfb_name
  export MFBENCH_${mfb_name^^}=$src_path
  tempo_envupd=1
}

function mfbench_listdir
{
  local dirkind=$(echo "MFBENCH_${1^^}" | tr [/] [_])
  local dirfull=${!dirkind}
  if [ -d "$dirfull" ]; then
    \cd $dirfull
    echo "$dirfull:"
    local inum=0
    for item in $(\ls -1); do
      inum=$((inum+1))
      printf "[%02d] %s\n" $inum $item 
    done
  else
    return 1
  fi
}

function mfbench_listdir_def
{
  local partdir=$(dirname $1)
  local partsub=$(basename $1)
  local partdef="${partsub^^}-SELECT.$MFBENCH_PROFILE"
  local dirkind=$(echo "MFBENCH_${partdir^^}" | tr [/] [_])
  local dirfull=${!dirkind}
  if [ -d "$dirfull" ]; then
    \cd $dirfull
    echo "$dirfull:"
    if [ "$2" == "" ]; then
      local ichoice=0
    else
      local ichoice=$2
      \rm -rf $partdef
    fi
    local inum=0
    local actualdef=$(\ls -l | fgrep "$partdef ->" | awk '{print $NF}')
    for item in $(\ls -1 $partsub*); do
      if [[ -f "$item" && "$item" != "$partdef" ]]; then
        inum=$((inum+1))
	    if [ $inum -eq $ichoice ]; then
          \ln -s $item $partdef	  
	      actualdef=$item
        fi
        local cstar=" "
        if [ "$item" == "$actualdef" ]; then
          cstar="*"
        fi
        printf "[%02d]%s %s\n" $inum "$cstar" "$item"
      fi
    done
  fi
}
