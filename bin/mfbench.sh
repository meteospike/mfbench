#!/bin/bash

# Set up/down default environment for running bench version of METEO-FRANCE codes
#
# Usage:
#   % mfb action [args...]
#
# List of commands:
#  % mfb help
#
# Initiate a new pack:
#  % mfb init (preferably as a source shell)
#
# Activate a session:
#  % mfb on (as a source shell)
# Exit from the current session:
#  % mfb off (as a source shell)

isnumber='^[0-9]+$'
isbundle='^bundle\-'
isyaml='\.ya?ml$'

if [[ $# == 0 ]]; then
    set -- "help"
elif [[ "$1" != "init" && "$1" != "on" && "$1" != "check" ]]; then
  if [ "$MFBENCH_ROOT" == "" ]; then
    set -- "on" $*
  fi
fi

while [[ $# -gt 0 ]]; do

  mfb=${1,,}
  shift

  if [ "$mfb" == "help" ]; then

    echo "-- SETTINGS ----------------"
    echo " + mfb version              : Display current mfbench version"
    echo " + mfb init                 : Set up default environment [.]"
    echo " + mfb on                   : Activate a sessioin [.]"
    echo " + mfb off                  : Turn off current sessioin [.]"
    echo " + mfb env                  : Display current mfbench environment"
    echo " + mfb omp                  : Display current OpenMP environment"
    echo " + mfb var [vars]           : Display specified env variables"
    echo " + mfb root                 : Display current mfbench root directory"
    echo " + mfb path                 : Display actual internal path"
    echo " + mfb list [all|items]     : List any mfbench directory"
    echo "-- INSTALL -----------------"
    echo " + mfb cmake                : Check CMake path and version"
    echo " + mfb fypp                 : Check Fypp path and version"
    echo " + mfb perl                 : Check Perl path and version"
    echo " + mfb yaml                 : Check Yaml module and version"
    echo " + mfb check                : Check all external tools versions"
    echo " + mfb sources [+-] [items] : Display or set bench components"
    echo " + mfb bundles              : List available bundles and set default"
    echo " + mfb bundle [item]        : Create install functions according to bundle"
    echo "-- INPUTS ------------------"
    echo " + mfb namless              : Show (with less) the main default namelist"
    echo " + mfb namedit              : Edit (with vim) the main default namelist"
    echo "-- EXECUTION ---------------"
    echo " + mfb play                 : Run the mfbench actual configuration"
    echo " + mfb redo                 : Make and Play"
    echo " + mfb job                  : Submit the mfbench job"
    echo " + mfb log [items]          : Display last log or search inside it [items]"
    echo " + mfb logdiff              : Compare last log output to reference"
    echo "-- OUTPUTS -----------------"
    echo " + mfb outputs [num]        : Change directory to last output or -num"
    echo " + mfb llout                : List output directories"
    echo " + mfb clrout               : Remove empty output directories"
    echo " + mfb rmlast               : Remove last output directory"
    echo " + mfb cmp                  : Binary comparaison between last execution and previous"
    echo " + mfb diff                 : Shortenen diff between last and previous run"
    echo " + mfb roll [yes|no]        : Rolling cmp on available outputs (continue or not if equal)"

  elif [ "$mfb" == "version" ]; then

    cat $MFBENCH_ROOT/VERSION

  elif [ "$mfb" == "init" ]; then

    if [[ ! -f "$PWD/bin/mfbench.sh" || ! -d "$PWD/jobs" ]]; then

      echo "You are probably not in a MFBENCH root directory" >&2
      break

    else

      export MFBENCH_ROOT=$PWD
      export MFBENCH_SESSION=${1:-void}

      export MFBENCH_STORE=$MFBENCH_ROOT/.mfb
      if [ ! -d $MFBENCH_STORE ]; then
        echo "Create local store $MFBENCH_STORE"
        mkdir $MFBENCH_STORE
      fi

      if [ -f "$MFBENCH_STORE/env.default" ]; then
        echo "Load default env values:"
        cat $MFBENCH_STORE/env.default
        set -a; source $MFBENCH_STORE/env.default; set +a
      fi

      for varname in $(env | fgrep MFBENCH_ | cut -d "=" -f1); do
        if [ "${!varname}" == "" ]; then
          unset $varname
        fi
      done

      export MFBENCH_CONF=$MFBENCH_ROOT/conf
      export MFBENCH_JOBS=$MFBENCH_ROOT/jobs
      export MFBENCH_SCRIPTS=$MFBENCH_ROOT/scripts
      export MFBENCH_SCRIPTS_FUNCTIONS=$MFBENCH_SCRIPTS/functions
      export MFBENCH_SCRIPTS_WRAPPERS=$MFBENCH_SCRIPTS/wrappers

      source $MFBENCH_SCRIPTS/functions/directories.sh

      TMPDIR=${TMPDIR:-$HOME/tmp}
      export MFBENCH_TMPDIR=${MFBENCH_TMPDIR:-$TMPDIR}
      mfbench_mkdir tmpdir

      WORKDIR=${WORKDIR:-$MFBENCH_TMPDIR}
      export MFBENCH_WORKDIR=${MFBENCH_WORKDIR:-$WORKDIR/mfbench}
      mfbench_mkdir workdir

      export MFBENCH_INSTALL=${MFBENCH_INSTALL:-$MFBENCH_ROOT/install}
      mfbench_mkdir_ln install $MFBENCH_ROOT

      export MFBENCH_PACK=${MFBENCH_PACK:-$MFBENCH_ROOT/pack}
      mfbench_mkdir_ln pack $MFBENCH_ROOT

      export MFBENCH_SOURCES=${MFBENCH_SOURCES:-$MFBENCH_ROOT/sources}
      mfbench_mkdir_ln sources $MFBENCH_ROOT

      export MFBENCH_DATA=$MFBENCH_ROOT/data
      mfbench_mkdir data

      export MFBENCH_INPUTS=${MFBENCH_INPUTS:-$MFBENCH_DATA/inputs}
      mfbench_mkdir_ln inputs $MFBENCH_DATA

      export MFBENCH_OUTPUTS=${MFBENCH_OUTPUTS:-$MFBENCH_DATA/outputs}
      mfbench_mkdir_ln outputs $MFBENCH_DATA

      export MFBENCH_REFS=${MFBENCH_REFS:-$MFBENCH_DATA/refs}
      mfbench_mkdir_ln refs $MFBENCH_DATA

      export MFBENCH_CMPLAST=yes
      export MFBENCH_TESTRUN=no
      export MFBENCH_RESTART=no

      if [ -f $MFBENCH_ROOT/VERSION ]; then
        export MFBENCH_XPID=v$(cat $MFBENCH_ROOT/VERSION)
      else
        export MFBENCH_XPID=test
      fi

      export OMP_NUM_THREADS=${OMP_NUM_THREADS:-1}
      export OMP_PLACES=${OMP_PLACES:-cores}      
      export OMP_PROC_BIND=${OMP_PROC_BIND:-close}
      export OMP_DISPLAY_ENV=${OMP_DISPLAY_ENV:-VERBOSE}

      unset MFBENCH_FUNCTIONS_DIRECTORIES
      env | fgrep MFBENCH_ > $MFBENCH_STORE/env.session.$MFBENCH_SESSION
      env | fgrep OMP_    >> $MFBENCH_STORE/env.session.$MFBENCH_SESSION

      \rm -f $MFBENCH_STORE/path.root
      echo "PATH=$PATH" > $MFBENCH_STORE/restore.session.$MFBENCH_SESSION
      if [[ ":$PATH:" == *":$MFBENCH_ROOT/bin:"* ]]; then
        echo "PATH already set"
      else
        PATH=$MFBENCH_ROOT/bin:$PATH
        echo "PATH=\$MFBENCH_ROOT/bin:\$PATH" > $MFBENCH_STORE/path.root
      fi

      echo "MFBENCH_ROOT=$MFBENCH_ROOT" > $HOME/.mfb_root
      echo "MFBENCH_SESSION=$MFBENCH_SESSION" > $HOME/.mfb_session

    fi

  elif [ "$mfb" == "on" ]; then

    if [ "$MFBENCH_ROOT" == "" ]; then
      if [ -f $HOME/.mfb_root ]; then
        set -a; source $HOME/.mfb_root; set +a
      else
        echo "Could not find out a mfbench root" >&2
        exit 1
      fi
    fi

    if [ "$MFBENCH_SESSION" == "" ]; then
      if [ -f $HOME/.mfb_session ]; then
        set -a; source $HOME/.mfb_session; set +a
      else
        echo "Could not find out a mfbench session" >&2
        exit 1
      fi
    fi

    if [ -f $MFBENCH_ROOT/.mfb/env.session.$MFBENCH_SESSION ]; then
      set -a
      source $MFBENCH_ROOT/.mfb/env.session.$MFBENCH_SESSION
      for filepath in $(\ls $MFBENCH_ROOT/.mfb/path.install.* $MFBENCH_ROOT/.mfb/path.root 2>/dev/null); do
        source $filepath
      done
      set +a
    else
      echo "Could not load the actual env session" >&2
      exit 1
    fi

  elif [ "$mfb" == "clear" ]; then

    \cd $MFBENCH_ROOT
    for thisdir in data/* data pack install; do
      if [ -d $thisdir ]; then
        echo "Try to remove $thisdir"
        rmdir $thisdir 2>/dev/null
      elif [ -L $thisdir ]; then
        \rm $thisdir
      fi
    done

  elif [ "$mfb" == "off" ]; then

    set -a; source $MFBENCH_STORE/restore.session.$MFBENCH_SESSION; set +a

    for fpvar in $(env | fgrep -e MFBENCH_ -e OMP_ -e KMP_ | fgrep -v _GRIBPACK | cut -f1 -d "="); do
      unset $fpvar
    done

  elif [ "$mfb" == "root" ]; then

    echo $MFBENCH_ROOT
    \cd $MFBENCH_ROOT

  elif [ "$mfb" == "path" ]; then

    echo "PATH=$PATH"

  elif [ "$mfb" == "env" ]; then

    env | fgrep MFBENCH_ | fgrep -v MFBENCH_OP_ | sort


  elif [ "$mfb" == "var" ]; then

    while [[ $# -gt 0 ]]; do
      varname="MFBENCH_${1^^}"
      echo "$varname=${!varname}"
      shift
    done

  elif [ "$mfb" == "omp" ]; then

    env | fgrep -e OMP_ -e KMP_ | sort

  elif [ "$mfb" == "sources" ]; then

    if [[ $# -ge 2 && ( "$1" == "+" || "$1" == "-" ) ]]; then
      if [ "$1" == "+" ]; then
        shift
        while [[ $# -gt 0 ]]; do
          item=$1
          shift
          if [ -e $item ]; then
            echo "Add to sources: $item"
            \cp $item $MFBENCH_SOURCES/$item
          fi
        done
      else
        shift
        while [[ $# -gt 0 ]]; do
          item=$1
          shift
          if [ -f $MFBENCH_SOURCES/$item ]; then
            echo "Remove from sources: $item"
            \rm $MFBENCH_SOURCES/$item
          fi
        done
      fi
    else
      set -- "list" "sources" $*
    fi

  elif [ "$mfb" == "list" ]; then

      if [ "$MFBENCH_FUNCTIONS_DIRECTORIES" != "true" ]; then
        source $MFBENCH_SCRIPTS/functions/directories.sh
      fi
      if [ $# -eq 0 ]; then
        set -- all
      fi
      while [[ $# -gt 0 ]]; do
        if [ "$1" == "all" ]; then
          shift
          set -- pack jobs conf inputs outputs refs sources install scripts/functions scripts/wrappers workdir $*
          continue
        fi
        mfbench_listdir $1
        if [[ $? == 0 ]]; then
          shift
        else
          break
        fi
      done

  elif [ "$mfb" == "data" ]; then

    set -- list inputs outputs refs $*

  elif [ "$mfb" == "fypp" ]; then

    fypp_command=$(which fypp 2>/dev/null)
    if [ $? == 0 ]; then
      fypp_version=$(fypp --version | cut -d " " -f2)
      echo "$fypp_command is $fypp_version"
    else
      echo "*** Fypp is not available, please install ***" >&2
    fi

  elif [ "$mfb" == "cmake" ]; then

    cmake_version=$(cmake --version | head -1 | cut -d " " -f3)
    echo "$(which cmake) is $cmake_version"
    if [[ $(echo $cmake_version|cut -d "." -f1) -eq 2 && $(echo $cmake_version|cut -d "." -f2) -lt 16 ]]; then
      echo "*** CMake is too old, please install new version ***" >&2
    fi

  elif [ "$mfb" == "perl" ]; then

    perl_version=$(perl -we 'print substr($^V,1);')
    echo "$(which perl) is $perl_version"
    if [ $(echo $perl_version | cut -d "." -f2) -lt 026 ]; then
      echo "*** Perl is too old, please install new version ***" >&2
    fi

  elif [ "$mfb" == "yaml" ]; then

    yaml_version=$(python3 -c "import yaml; print(yaml.__version__)" 2>/dev/null)
    if [ $? == 0 ]; then
      yaml_module=$(python3 -c "import os, yaml; print(os.path.dirname(yaml.__file__))")
      echo "$yaml_module is $yaml_version"
    else
      echo "*** Python module yaml is not available, please install ***"
    fi

  elif [ "$mfb" == "check" ]; then

    set -- cmake fypp perl yaml $*

  elif [ "$mfb" == "bundles" ]; then

    if [ "$MFBENCH_FUNCTIONS_DIRECTORIES" != "true" ]; then
      source $MFBENCH_SCRIPTS/functions/directories.sh
    fi

    if [[ $# -gt 0 && $1 =~ $isnumber ]]; then
      inum=$1
      shift
    fi

    mfbench_listdir_def conf/bundle $inum

  elif [ "$mfb" == "bundle" ]; then

    if [ $# -gt 0 ]; then
      bdlname=$1
      shift
      if [[ ! "$bdlname" =~ "$isbundle" ]]; then
        bdlname="bundle-$bdlname"
      fi
      if [[ ! "$bdlname" =~ "$isyaml" ]]; then
        bdlname="$bdlname.yml"
      fi
    else
      bdlname='BUNDLE-DEFAULT'
    fi

    if [ -f "$MFBENCH_CONF/$bdlname" ]; then
      echo "Create install procedures according to $bdlname"
    else
      echo "Could not find $bdlname" >&2
    fi

  elif [ "$mfb" == "install" ]; then

    echo "TODO"

  elif [ "$mfb" == "uninstall" ]; then

    echo "TODO"

  else

    echo "Warning: subcommand '$mfb' not found" >&2

 fi

done
