#!/bin/bash

# Set up default environment for running bench version of METEO-FRANCE codes
#
# Usage:
#   % mfb [action1] [args1...] [action2...] [args2...] [...]
#
# List of commands:
#  % mfb help
#
# Initiate a new pack:
#  % mfb init
#
# Activate a session:
#  % mfb on (possibly as a source shell)
# Exit from the current session:
#  % mfb off (possibly as a source shell)

isnumber='^[0-9]+$'
isbundle='^bundle\-'
isyaml='\.ya?ml$'

function check_private () {
  if [ "$tempo_private" == "true" ]; then
    tempo_private=false
  else
    echo "Subcommand '$mfb' is internal only" >&2
    exit 1
  fi
}

function mandatory_var_raw ()
{
  for this_var in $*; do
    actual_var=MFBENCH_${this_var^^}
    if [ "${!actual_var}" == "" ]; then
      echo "Variable $actual_var is not set" >&2
      exit 1
    fi
  done
}

function mandatory_var_msg ()
{
  this_msg=$1
  shift
  for this_var in $*; do
    actual_var=MFBENCH_${this_var^^}
    if [ "${!actual_var}" == "" ]; then
      echo "Variable $actual_var must be defined for $this_msg" >&2
      exit 1
    fi
  done
}

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

if [[ $# == 0 ]]; then
    set -- help
elif [[ "$1" != "init" && "$1" != "on" && "$1" != "linkable" ]]; then
  if [ "$MFBENCH_ROOT" == "" ]; then
    set -- on $*
  fi
fi

while [[ $# -gt 0 ]]; do

  mfb=${1,,}
  shift

  if [ "$mfb" == "help" ]; then

    [[ $# -eq 0 ]] && set -- settings install compile inputs execution outputs

    while [[ $# -gt 0 ]]; do

      chapter=${1,,}
      shift

      if [ "$chapter" = "settings" ]; then
        echo "-- SETTINGS ----------------"
        echo " + mfb version              : Display current mfbench version"
        echo " + mfb init                 : Set up default environment"
        echo " + mfb on                   : Activate a session"
        echo " + mfb off                  : Turn off current session"
        echo " + mfb root                 : Display current mfbench root directory"
        echo " + mfb profile              : Display current profile name"
        echo " + mfb pcunit               : Display current processing unit family (std/gpu)"
        echo " + mfb env                  : Display current mfbench environment"
        echo " + mfb omp                  : Display current OpenMP environment"
        echo " + mfb var [vars]           : Display specified env variables"
        echo " + mfb get [vars]           : Get the actual value of the specified env variables"
        echo " + mfb set [var] [value]    : Set the env variable to specified value"
        echo " + mfb unset [vars]         : Unset the specified env variables"
        echo " + mfb path                 : Display actual internal path"
        echo " + mfb list [all|items]     : List any mfbench directory"
      fi

      if [ "$chapter" = "install" ]; then
        echo "-- INSTALL -----------------"
        echo " + mfb bundle               : List available bundles and set default"
        echo " + mfb select-bundle        : Select a default bundle according to current mode"
        echo " + mfb bundle-map           : Show items in the current bundle by type"
        echo " + mfb bundle-list          : List all types in the current bundle in a raw"
        echo " + mfb bundle-flat          : List all items in the current bundle in a raw"
        echo " + mfb bundle-arch          : List all items in the current bundle with arch and pack options"
        echo " + mfb arch                 : Display actual arch value"
        echo " + mfb opts                 : Display actual opts value"
        echo " + mfb sources [+-] [items] : Display or set bench components"
        echo " + mfb cmake                : Check CMake path and version"
        echo " + mfb fypp                 : Check Fypp path and version"
        echo " + mfb perl                 : Check Perl path and version"
        echo " + mfb yaml                 : Check Yaml module and version"
        echo " + mfb check                : Check all external tools versions"
        echo " + mfb python               : Check Python path and version and seaarch path for modules"
        echo " + mfb installed            : List local install items"
        echo " + mfb track [items]        : List local install files for items"
      fi

      if [ "$chapter" = "compile" ]; then
        echo "-- COMPILE------------------"
        echo " + mfb gmkfile              : List available gmkfiles and set default"
        echo " + mfb select-gmkfile       : Select a default gmkfile according to arch and opts"
        echo " + mfb mkmain               : Create a complete base pack including hub and main"
        echo " + mfb mkpack               : Create an incremental pack on top of a previous one"
        echo " + mfb rmpack [pack]        : Remove specified pack or current pack"
        echo " + mfb fixpack              : Apply existing filters functions on ics/ild files"
        echo " + mfb pack                 : Display the full path of the current pack"
        echo " + mfb nest                 : Set the current directory as the current pack"
        echo " + mfb compile              : Compile through ics files in the current pack"
        echo " + mfb clean                : Clean and reset the current pack"
      fi

      if [ "$chapter" = "inputs" ]; then
        echo "-- INPUTS ------------------"
        echo " + mfb inputs               : List available input configurations"
      fi

      if [ "$chapter" = "execution" ]; then
        echo "-- EXECUTION ---------------"
        echo " + mfb play                 : Run the mfbench actual configuration"
        echo " + mfb redo                 : Make and Play"
      fi

      if [ "$chapter" = "outputs" ]; then
        echo "-- OUTPUTS -----------------"
        echo " + mfb outputs              : List actual outputs directories"
      fi
    done

  elif [ "$mfb" == "fake" ]; then

    tempo_fake=true

  elif [ "$mfb" == "version" ]; then

    echo "This is mfbench $(cat $MFBENCH_ROOT/VERSION) at $MFBENCH_ROOT"

  elif [ "$mfb" == "linkable" ]; then

    cut -d ":" -f 1 $(dirname $(realpath $0))/../conf/mfbench-optlink

  elif [ "$mfb" == "init" ]; then

    [[ -f ../bin/mfbench.sh && -d ../jobs ]] && \cd ..

    if [[ ! -f "$PWD/bin/mfbench.sh" || ! -d "$PWD/jobs" ]]; then
      echo "You are probably not in a MFBENCH root directory" >&2
      break
    fi

    export MFBENCH_ROOT=$PWD
    export MFBENCH_PROFILE=${1:-default}
    export MFBENCH_ARCH=$ARCH
    export MFBENCH_PCUNIT=std
    export MFBENCH_AUTOPACK=yes

    export MFBENCH_STORE=$MFBENCH_ROOT/.mfb
    if [ ! -d $MFBENCH_STORE ]; then
      echo "Create store directory: $MFBENCH_STORE"
      mkdir $MFBENCH_STORE
    fi

    if [ -f "$HOME/.mfbrc" ]; then
      echo "Load user preferences:"
      cat $HOME/.mfbrc
      set -a; source $HOME/.mfbrc; set +a
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

    source $MFBENCH_SCRIPTS_FUNCTIONS/directories.sh

    export MFBENCH_PROFDIR=$MFBENCH_STORE/profile_$MFBENCH_PROFILE
    mfbench_mkdir profdir

    export MFBENCH_TRACKDIR=$MFBENCH_STORE/install_tracking
    mfbench_mkdir trackdir

    export TMPDIR=${TMPDIR:-$HOME/tmp}
    export MFBENCH_TMPDIR=${MFBENCH_TMPDIR:-$TMPDIR}
    mfbench_mkdir tmpdir

    export WORKDIR=${WORKDIR:-$MFBENCH_TMPDIR}
    export MFBENCH_WORKDIR=${MFBENCH_WORKDIR:-$WORKDIR/mfbench}
    mfbench_mkdir workdir

    export MFBENCH_BUILD=${MFBENCH_BUILD:-$MFBENCH_ROOT/build}
    mfbench_mkdir_ln build $MFBENCH_ROOT

    export MFBENCH_INSTALL=${MFBENCH_INSTALL:-$MFBENCH_ROOT/install}
    mfbench_mkdir_ln install $MFBENCH_ROOT

    export MFBENCH_PACKS=${MFBENCH_PACKS:-$MFBENCH_ROOT/packs}
    mfbench_mkdir_ln packs $MFBENCH_ROOT

    export MFBENCH_SOURCES=${MFBENCH_SOURCES:-$MFBENCH_ROOT/sources}
    mfbench_mkdir_ln sources $MFBENCH_ROOT

    export MFBENCH_SUPPORT=$MFBENCH_ROOT/support
    export MFBENCH_SUPPORT_ARCH=$MFBENCH_SUPPORT/arch
    export MFBENCH_SUPPORT_LINK=$MFBENCH_SUPPORT/link
    mfbench_mkdir support

    export MFBENCH_DATA=$MFBENCH_ROOT/data
    mfbench_mkdir data

    export MFBENCH_INPUTS=${MFBENCH_INPUTS:-$MFBENCH_DATA/inputs}
    mfbench_mkdir_ln inputs $MFBENCH_DATA

    export MFBENCH_OUTPUTS=${MFBENCH_OUTPUTS:-$MFBENCH_DATA/outputs}
    mfbench_mkdir_ln outputs $MFBENCH_DATA

    export MFBENCH_REFS=${MFBENCH_REFS:-$MFBENCH_DATA/refs}
    mfbench_mkdir_ln refs $MFBENCH_DATA

    if [ -f $MFBENCH_ROOT/VERSION ]; then
      export MFBENCH_XPID=v$(cat $MFBENCH_ROOT/VERSION)
    else
      export MFBENCH_XPID=test
    fi

    export OMP_NUM_THREADS=${OMP_NUM_THREADS:-1}
    export OMP_PLACES=${OMP_PLACES:-cores}
    export OMP_PROC_BIND=${OMP_PROC_BIND:-close}
    export OMP_DISPLAY_ENV=${OMP_DISPLAY_ENV:-VERBOSE}

    \rm -f $MFBENCH_PROFDIR/path.root
    echo "PYTHONPATH=$PYTHONPATH" > $MFBENCH_PROFDIR/restore.profile
    echo "PATH=$PATH"            >> $MFBENCH_PROFDIR/restore.profile

    if [[ ":$PATH:" == *":$MFBENCH_ROOT/bin:"* ]]; then
      echo "PATH already set"
    else
      PATH=$MFBENCH_ROOT/bin:$PATH
      echo "PATH=\$MFBENCH_ROOT/bin:\$PATH" > $MFBENCH_PROFDIR/path.root
    fi

    echo "MFBENCH_ROOT=$MFBENCH_ROOT" > $HOME/.mfb_root
    echo "MFBENCH_PROFILE=$MFBENCH_PROFILE" > $HOME/.mfb_profile

    set -- setenv $*

  elif [ "$mfb" == "link" ]; then

    if [ $# -ne 2 ]; then
      echo "Usage: mfb link mfbench-dir source-dir"
      exit 1
    fi

    [[ "$MFBENCH_FUNCTIONS_DIRECTORIES" != "true" ]] && source $MFBENCH_SCRIPTS_FUNCTIONS/directories.sh

    export tempo_envupd=0
    mfbench_renew_ln $1 $2

    if [ $tempo_envupd -eq 1 ]; then
      set -- setenv
    else
      set --
    fi

  elif [ "$mfb" == "setenv" ]; then

    echo "Freezing current mfbench environment"

    unset $(env | fgrep MFBENCH_FUNCTIONS_ | cut -d "=" -f1)

    env | fgrep MFBENCH_ | sort -u > $MFBENCH_PROFDIR/env.profile
    env | fgrep OMP_     | sort -u > $MFBENCH_PROFDIR/env.omp

  elif [ "$mfb" == "on" ]; then

    if [ "$MFBENCH_ROOT" == "" ]; then
      if [ -f $HOME/.mfb_root ]; then
        set -a; source $HOME/.mfb_root; set +a
      else
        echo "Could not find out a mfbench root" >&2
        exit 1
      fi
    fi

    if [ "$MFBENCH_PROFILE" == "" ]; then
      if [ -f $HOME/.mfb_profile ]; then
        set -a; source $HOME/.mfb_profile; set +a
      else
        echo "Could not find out a mfbench profile" >&2
        exit 1
      fi
    fi

    export MFBENCH_PROFDIR=$MFBENCH_ROOT/.mfb/profile_$MFBENCH_PROFILE

    if [ -f $MFBENCH_PROFDIR/env.profile ]; then
      set -a
      source $MFBENCH_PROFDIR/env.profile
      for extend_env in $(\ls \
        $MFBENCH_PROFDIR/env.omp \
        $MFBENCH_PROFDIR/env.install.* \
        $MFBENCH_PROFDIR/python.install.*  \
        $MFBENCH_PROFDIR/path.install.* \
        $MFBENCH_PROFDIR/path.root \
        2>/dev/null); do
        source $extend_env
      done
      set +a
    else
      echo "Could not load the actual env profile" >&2
      exit 1
    fi

  elif [ "$mfb" == "off" ]; then

    set -a; source $MFBENCH_PROFDIR/restore.profile; set +a

    for fpvar in $(env | fgrep -e MFBENCH_ -e OMP_ -e KMP_ | fgrep -v _GRIBPACK | cut -f1 -d "="); do
      unset $fpvar
    done

  elif [ "$mfb" == "root" ]; then

    echo $MFBENCH_ROOT
    \cd $MFBENCH_ROOT

  elif [ "$mfb" == "profile" ]; then

    echo $MFBENCH_PROFILE

  elif [ "$mfb" == "pcunit" ]; then

    echo $MFBENCH_PCUNIT

  elif [ "$mfb" == "profdir" ]; then

      \cd $MFBENCH_PROFDIR
      pwd
      \ls -l

  elif [ "$mfb" == "arch" ]; then

    if [ "$MFBENCH_ARCH" == "" ]; then
      echo "Variable MFBENCH_ARCH is not set"
    else
      echo $MFBENCH_ARCH
    fi

  elif [ "$mfb" == "opts" ]; then

    if [ "$MFBENCH_OPTS" == "" ]; then
      echo "Variable MFBENCH_OPTS is not set"
    else
      echo $MFBENCH_OPTS
    fi

  elif [ "$mfb" == "path" ]; then

    echo "PATH=$PATH"

  elif [ "$mfb" == "env" ]; then

    env | fgrep MFBENCH_ | fgrep -v MFBENCH_OP_ | sort

  elif [ "$mfb" == "var" ]; then

    while [[ $# -gt 0 ]]; do
      varname="MFBENCH_${1^^}"
      shift
      if [ "${!varname}" == "" ]; then
        echo "Variable $varname is not set"
      else
        echo "$varname=${!varname}"
      fi
    done

  elif [ "$mfb" == "get" ]; then

    while [[ $# -gt 0 ]]; do
      varname="MFBENCH_${1^^}"
      shift
      if [ "${!varname}" != "" ]; then
        echo "${!varname}"
      fi
    done

  elif [ "$mfb" == "set" ]; then

    if [[ $# -lt 2 ]]; then
      echo "Usage: mfb set varname value" >&2
      exit 1
    fi

    this_var="MFBENCH_${1^^}"
    shift
    this_value=$1
    shift

    echo $this_var=$this_value
    export $this_var=$this_value
    set -- setenv

  elif [ "$mfb" == "unset" ]; then

    tempo_envupd=0
    while [[ $# -gt 0 ]]; do
      this_var="MFBENCH_${1^^}"
      shift
      if [ "${!this_var}" == "" ]; then
        echo "Ignore ${this_var}"
      else
        echo "Unset ${this_var}"
        unset ${this_var}
        tempo_envupd=1
      fi
    done

    [[ $tempo_envupd -eq 1 ]] && set -- setenv

  elif [ "$mfb" == "omp" ]; then

    env | fgrep -e OMP_ -e KMP_ | sort


  elif [ "$mfb" == "gmk" ]; then

    env | fgrep -e GMK -e HOMEPACK -e ROOTPACK -e HOMEBIN -e ROOTBIN | sort

  elif [ "$mfb" == "gmkfile" ]; then

    [[ "$MFBENCH_FUNCTIONS_DIRECTORIES" != "true" ]] && source $MFBENCH_SCRIPTS_FUNCTIONS/directories.sh

    if [[ $# -gt 0 && $1 =~ $isnumber ]]; then
      inum=$1
      shift
    fi

    mfbench_listdir_def support/arch/GMKFILE $inum

  elif [ "$mfb" == "select-gmkfile" ]; then

    \cd $MFBENCH_SUPPORT_ARCH
    \rm -f GMKFILE-SELECT.$(mfb profile)
    echo "Select gmkfile-$MFBENCH_ARCH.$MFBENCH_OPTS as default GMKFILE"
    \ln -s gmkfile-$MFBENCH_ARCH.$MFBENCH_OPTS GMKFILE-SELECT.$MFBENCH_PROFILE

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

    [[ "$MFBENCH_FUNCTIONS_DIRECTORIES" != "true" ]] && source $MFBENCH_SCRIPTS_FUNCTIONS/directories.sh

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

  elif [ "$mfb" == "python" ]; then

    python_version=$(python3 --version | cut -d " " -f2)
    echo "$(which python3) is $python_version"
    echo "PYTHONPATH=$PYTHONPATH"

  elif [ "$mfb" == "check" ]; then

    set -- cmake fypp perl yaml $*

  elif [ "$mfb" == "bundle-list" ]; then

    exec bundle.py --list

  elif [ "$mfb" == "bundle-flat" ]; then

    exec bundle.py --flat

  elif [ "$mfb" == "bundle-arch" ]; then

    exec bundle.py --arch | sort -u

  elif [ "$mfb" == "bundle-map" ]; then

    exec bundle.py --cmap

  elif [ "$mfb" == "bundle" ]; then

    [[ "$MFBENCH_FUNCTIONS_DIRECTORIES" != "true" ]] && source $MFBENCH_SCRIPTS_FUNCTIONS/directories.sh

    if [[ $# -gt 0 && $1 =~ $isnumber ]]; then
      inum=$1
      shift
    fi

    mfbench_listdir_def conf/bundle $inum

  elif [ "$mfb" == "select-bundle" ]; then

    \cd $MFBENCH_CONF
    \rm -f BUNDLE-SELECT.$MFBENCH_PROFILE
    echo "Select bundle-${MFBENCH_PCUNIT}pack.yml as default bundle"
    \ln -s bundle-${MFBENCH_PCUNIT}pack.yml BUNDLE-SELECT.$MFBENCH_PROFILE

  elif [ "$mfb" == "process" ]; then

    this_todo=$1
    shift

    bundle_items=$(bundle.py --flat)
    bundle_items=${bundle_items// /:}
    bundle_types=$(bundle.py --list)
    bundle_types=${bundle_types// /:}

    while [[ $# -gt 0 ]]; do

      if [[ ":$bundle_types:" == *":$1:"* ]]; then
        this_type=$1
        shift
        echo "Insert all '$this_type' type items"
        set -- $(bundle.py --type $this_type) $*
      fi

      if [[ ! ":$bundle_items:" == *":$1:"* ]]; then
        echo "Item '$1' is unknown in the current bundle" >&2
        exit 1
      fi

      this_item=$1
      shift

      for fpvar in $(env | fgrep -e MFBENCH_INSTALL_ | cut -f1 -d "="); do
        unset $fpvar
      done

      bundle.py --item $this_item > $MFBENCH_STORE/$this_todo.current
      if [[ $? != 0 ]]; then
        echo "Unable to set env for $this_todo of $this_item"
        break
      fi

      cat $MFBENCH_STORE/$this_todo.current
      set -a; source $MFBENCH_STORE/$this_todo.current; set +a
      \rm -rf $MFBENCH_STORE/$this_todo.current

      [[ "$MFBENCH_INSTALL_GMKPACK" == "yes" ]] && mandatory_var_msg "$this_todo '$this_item'" pack

      if [ "$MFBENCH_INSTALL_MKARCH"  == "yes" ]; then
        mandatory_var_msg "$this_todo '$this_item'" arch opts
        export MFBENCH_INSTALL_TRACKEXT=$MFBENCH_ARCH
      else
        export MFBENCH_INSTALL_TRACKEXT="shared"
      fi


      [[ "$tempo_fake" == "true" ]] && continue

      if [ "$MFBENCH_FUNCTIONS_INSTALLS" != "true" ]; then
        source $MFBENCH_SCRIPTS_FUNCTIONS/installs.sh
      fi

      if [ ! -d $MFBENCH_INSTALL_TARGET ]; then
        echo "Creating directory $MFBENCH_INSTALL_TARGET"
        mkdir -p $MFBENCH_INSTALL_TARGET
      fi

      if [ "$MFBENCH_INSTALL_MKARCH"  == "yes" ]; then
        source $MFBENCH_SCRIPTS_WRAPPERS/setup_compilers.sh
        export CC=$MFBENCH_COMPILER_CC
        export FC=$MFBENCH_COMPILER_F90
        export CXX=$MFBENCH_COMPILER_CXX
        export F90=$MFBENCH_COMPILER_F90
        export F77=$MFBENCH_COMPILER_F90
      fi

      this_under=${this_item//-/_}
      mfbench_${this_todo}_track_in $this_under

      todo_function="mfbench_${this_todo}_${this_under}"
      type_function="mfbench_${this_todo}_${MFBENCH_INSTALL_TYPE}"
      if [[ "$(declare -F $todo_function)" == "$todo_function" ]]; then
        echo "Processing specific $this_todo function $todo_function"
        $todo_function
      elif [[ "$(declare -F $type_function)" == "$type_function" ]]; then
        echo "Processing type $this_todo function $type_function"
        $type_function
      else
        echo "Processing generic $this_todo for $this_item"
        mfbench_${this_todo}_generic
      fi

      post_function="mfbench_post_${this_todo}_${this_under}"
      type_function="mfbench_post_${this_todo}_${MFBENCH_INSTALL_TYPE}"
      if [[ "$(declare -F $post_function)" == "$post_function" ]]; then
        echo "Processing specific post $this_todo function $post_function"
        $post_function
      elif [[ "$(declare -F $type_function)" == "$type_function" ]]; then
        echo "Processing type post $this_todo function $type_function"
        $type_function
      else
        echo "No post $this_todo to be done"
      fi

      mfbench_${this_todo}_track_out $this_under

    done

  elif [ "$mfb" == "install" ]; then

    set -- process install $*

  elif [ "$mfb" == "uninstall" ]; then

    set -- process uninstall $*

  elif [ "$mfb" == "installed" ]; then

    \cd $MFBENCH_TRACKDIR
    \ls -1 track.*.shared track.*.$MFBENCH_ARCH 2>/dev/null | sort -u | cut -f2 -d "."

  elif [ "$mfb" == "track" ]; then

    for this_file in $*; do
      this_item=${this_file//-/_}
      for this_arch in shared $MFBENCH_ARCH; do
        if [ -f "$MFBENCH_TRACKDIR/track.$this_item.$this_arch" ]; then
          cat $MFBENCH_TRACKDIR/track.$this_item.$this_arch
          continue
        fi
      done
    done

    set --

  elif [ "$mfb" == "pack" ]; then

    mandatory_var_msg "'$mfb'" packs

    if [ "$MFBENCH_PACK" == "" ]; then
      mandatory_var_raw arch opts
      this_cycle=${MFBENCH_CYCLE:-$(cat $MFBENCH_CONF/gmkpack-cycle)}
      this_branch=${MFBENCH_BRANCH:-rapsmain}
      this_packid=${MFBENCH_PACKID:-01}
      echo "$MFBENCH_PACKS/${this_cycle}_${this_branch}.$this_packid.$MFBENCH_ARCH.$MFBENCH_OPTS"
    else
      echo "$MFBENCH_PACKS/$MFBENCH_PACK"
    fi

  elif [ "$mfb" == "nest" ]; then

    mandatory_var_msg "'$mfb'" packs

    this_root=$(dirname $PWD)
    this_pack=$(basename $PWD)

    if [ "$this_root" != "$MFBENCH_PACKS" ]; then
      echo "This is not a proper location for a pack" >&2
      exit 1
    fi

    export MFBENCH_PACK=$this_pack
    \ls src/inter.1 2>/dev/null
    if [ $? -eq 0 ]; then
      export MFBENCH_LASTPACK=$this_pack
    else
      unset MFBENCH_LASTPACK
      export MFBENCH_MAINPACK=$this_pack
    fi

    set -- setenv

  elif [ "$mfb" == "mkmain" ]; then

    mandatory_var_msg "'$mfb'" packs arch opts

    this_cycle=${MFBENCH_CYCLE:-$(cat $MFBENCH_CONF/gmkpack-cycle)}
    this_branch=${MFBENCH_BRANCH:-rapsmain}
    this_packid=${MFBENCH_PACKID:-01}

    while [[ $# -gt 0 ]]; do
      if [[ $1 =~ $isnumber ]]; then
        this_packid=$1
      else
        this_branch=$1
      fi
      shift
    done

    this_packid=$(printf "%02d" $this_packid)

    export MFBENCH_PACK=${this_cycle}_${this_branch}.$this_packid.$MFBENCH_ARCH.$MFBENCH_OPTS

    \cd $MFBENCH_PACKS
    if [ -d $MFBENCH_PACK ]; then
      echo "Pack $MFBENCH_PACK already created"
      continue
    fi

    echo "Creating base pack $MFBENCH_PACK"
    [[ "$tempo_fake" == "true" ]] && continue

    gmkpack \
      -r $this_cycle  \
      -b $this_branch \
      -n $this_packid \
      -l $MFBENCH_ARCH -o $MFBENCH_OPTS -a -K -p $(cat $MFBENCH_CONF/gmkpack-binaries)

    export MFBENCH_MAINPACK=$MFBENCH_PACK

    if [ "$MFBENCH_AUTOPACK" == "yes" ]; then
      set -- setenv fixpack install $(bundle.py --type hub) $(bundle.py --type main)
    else
      set -- setenv fixpack
    fi

  elif [ "$mfb" == "mkpack" ]; then

    mandatory_var_msg "'$mfb'" arch opts packs mainpack

    main_cycle=$(echo $MFBENCH_MAINPACK | cut -d "." -f1 | cut -d "_" -f1)
    main_branch=$(echo $MFBENCH_MAINPACK | cut -d "." -f1 | cut -d "_" -f2)
    main_packid=$(echo $MFBENCH_MAINPACK | cut -d "." -f2)

    while [[ $# -gt 0 ]]; do
      if [[ $1 =~ $isnumber ]]; then
        this_packid=$1
      else
        this_branch=$1
      fi
      shift
    done

    if [ "$MFBENCH_LASTPACK" == "" ]; then
      last_branch=${main_branch//main/dev}
      base_branch=$main_branch
      last_packid=00
      base_packid=$main_packid
    else
      last_branch=$(echo $MFBENCH_LASTPACK | cut -d "." -f1 | cut -d "_" -f2)
      base_branch=$last_branch
      last_packid=$(echo $MFBENCH_LASTPACK | cut -d "." -f2)
      base_packid=$last_packid
    fi

    if [ "$this_branch" == "" ]; then
      this_branch=$last_branch
    fi

    if [ "$this_packid" == "" ]; then
      this_packid=$(($last_packid+1))
    fi

    this_packid=$(printf "%02d" $this_packid)

    export MFBENCH_PACK=${main_cycle}_${this_branch}.$this_packid.$MFBENCH_ARCH.$MFBENCH_OPTS

    \cd $MFBENCH_PACKS

    if [ -d $MFBENCH_PACK ]; then
      echo "Pack $MFBENCH_PACK already created"
      continue
    fi

    echo "Creating base pack $MFBENCH_PACK"
    [[ "$tempo_fake" == "true" ]] && continue

    gmkpack \
      -r $main_cycle  \
      -b $base_branch \
      -u $this_branch \
      -n $this_packid \
      -v $base_packid \
      -l $MFBENCH_ARCH -o $MFBENCH_OPTS -p $(cat $MFBENCH_CONF/gmkpack-binaries)

    export MFBENCH_LASTPACK=$MFBENCH_PACK
    set -- setenv fixpack

  elif [ "$mfb" == "fixpack" ]; then

    mandatory_var_raw packs pack conf

    if [ "$MFBENCH_FUNCTIONS_COMPILE" != "true" ]; then
      source $MFBENCH_SCRIPTS_FUNCTIONS/compile.sh
    fi

    \cd $MFBENCH_PACKS/$MFBENCH_PACK
    for compile_func in $(declare -F | fgrep mfbench_compile_ | cut -d " " -f3 | sort -u); do
      echo "Apply function $compile_func..."
      $compile_func
    done

  elif [ "$mfb" == "rmpack" ]; then

    mandatory_var_raw packs pack

    if [ $# -gt 0 ]; then
      this_pack=$1
      shift
    else
      this_pack=$MFBENCH_PACK
    fi

    \cd $MFBENCH_PACKS
    echo "Removing $this_pack..."
    [[ "$tempo_fake" == "true" ]] && continue
    \rm -rf $this_pack

    [[ "$this_pack" == "$MFBENCH_LASTPACK" ]] && unset MFBENCH_LASTPACK
    [[ "$this_pack" == "$MFBENCH_MAINPACK" ]] && unset MFBENCH_MAINPACK

    unset MFBENCH_PACK

    set -- setenv

  elif [ "$mfb" == "compilers" ]; then

    source $MFBENCH_SCRIPTS_WRAPPERS/setup_compilers.sh

  elif [ "$mfb" == "build" ]; then

    check_private
    mandatory_var_raw packs
    \cd $MFBENCH_PACKS

    if [ "$MFBENCH_PACK" == "" ]; then
      mandatory_var_raw arch opts
      export MFBENCH_PACK=$(\ls -tr1d *.*.$MFBENCH_ARCH.$MFBENCH_OPTS | tail -1)
    fi

    if [ "$MFBENCH_FUNCTIONS_COMPILE" != "true" ]; then
      source $MFBENCH_SCRIPTS_FUNCTIONS/compile.sh
    fi

    source $MFBENCH_SCRIPTS_WRAPPERS/setup_compilers.sh

    \cd $MFBENCH_PACKS/$MFBENCH_PACK
    pwd

    build_prefix=$1
    shift

    [[ $# -eq 0 ]] && set -- $(cat $MFBENCH_CONF/gmkpack-packages $MFBENCH_CONF/gmkpack-binaries)

    while [[ $# -gt 0 ]]; do
      this_builder="${build_prefix}_$1"
      shift
      if [ -f $this_builder ]; then
        echo "Build $this_builder"
        [[ "$tempo_fake" != "true" ]] && ./$this_builder 2>&1 | tee $(mfbench_logfile $this_builder)
      else
        echo "No such builder: $this_builder" >&2
      fi
    done

    [[ -d hub/local/build ]] && \rm -rf hub/local/build

  elif [ "$mfb" == "compile" ]; then

    tempo_private=true
    set -- build ics $*

  elif [ "$mfb" == "load" ]; then

    tempo_private=true
    set -- build ild $*

  elif [ "$mfb" == "clean" ]; then

    mandatory_var_raw packs pack
    \cd $MFBENCH_PACKS/$MFBENCH_PACK
    cleanpack
    resetpack

  elif [ "$mfb" == "inputs" ]; then

    echo "TODO..."

  elif [ "$mfb" == "play" ]; then

    \cd $MFBENCH_JOBS

    while [[ $# -gt 0 ]]; do
      this_play=$1
      shift
      exec ./$this_play.sh
    done

  elif [ "$mfb" == "redo" ]; then

    set -- compile play

  elif [ "$mfb" == "outputs" ]; then

    echo "TODO..."

  elif [ "$mfb" == "tube" ]; then

    exec $*
    set --

  else

    echo "Warning: subcommand '$mfb' not found" >&2

 fi

done
