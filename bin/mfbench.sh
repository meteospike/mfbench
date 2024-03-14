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
thiscallpath=$(dirname $(realpath $0))
source $thiscallpath/utils.sh

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

    [[ $# -eq 0 ]] && set -- settings install compile execution

    set -- autodoc $*

  elif [ "$mfb" == "fake" ]; then
    #:execution:fake: Do not complete a full execution of the command

    tempo_fake=true

  elif [ "$mfb" == "autodoc" ]; then
    #:settings:autodoc: Display help page for sections

    exec $thiscallpath/autodoc.py $*
    set --

  elif [ "$mfb" == "version" ]; then
    #:settings:version: Display mfbench version

    echo "This is mfbench $(cat $MFBENCH_ROOT/VERSION) at $MFBENCH_ROOT"

  elif [ "$mfb" == "linkable" ]; then
    #:settings:linkable: List of candidate directories to external linking

    cut -d ":" -f 1 $(dirname $(realpath $0))/../conf/mfbench-optlink

  elif [ "$mfb" == "init" ]; then
    #:settings:init: Set up default environment

    [[ -f ../bin/mfbench.sh && -d ../jobs ]] && \cd ..

    if [[ ! -f "$PWD/bin/mfbench.sh" || ! -d "$PWD/jobs" ]]; then
      echo "You are probably not in a MFBENCH root directory" >&2
      break
    fi

    export MFBENCH_ROOT=$PWD
    export MFBENCH_PROFILE=${1:-default}
    export MFBENCH_ARCH=$ARCH
    export MFBENCH_PCUNIT="std"
    export MFBENCH_GPUKIND="cc70,cc80"
    export MFBENCH_AUTOPACK="yes"
    export MFBENCH_RMBUILD="yes"

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

    export MFBENCH_TMPDIR=${MFBENCH_TMPDIR:-$HOME/tmp}
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
    mfbench_mkdir support
    [[ ! -L $MFBENCH_SUPPORT/arch ]] && \ln -s $MFBENCH_CONF $MFBENCH_SUPPORT/arch

    export MFBENCH_DATA=$MFBENCH_ROOT/data
    mfbench_mkdir data

    export MFBENCH_NAMELISTS=$MFBENCH_ROOT/data/namelists
    mfbench_mkdir namelists

    export MFBENCH_INPUTS=${MFBENCH_INPUTS:-$MFBENCH_DATA/inputs}
    mfbench_mkdir_ln inputs $MFBENCH_DATA

    export MFBENCH_OUTPUTS=${MFBENCH_OUTPUTS:-$MFBENCH_DATA/outputs}
    mfbench_mkdir_ln outputs $MFBENCH_DATA

    export MFBENCH_REFERENCES=${MFBENCH_REFERENCES:-$MFBENCH_DATA/references}
    mfbench_mkdir_ln references $MFBENCH_DATA

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
    #:settings:link [mfbdir] [srcdir]: Set external link directory"

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
    #:settings:setenv: Freeze current environment

    unset $(env | fgrep MFBENCH_FUNCTIONS_ | cut -d "=" -f1)

    env | fgrep MFBENCH_ | sort -u > $MFBENCH_PROFDIR/env.profile
    env | fgrep OMP_     | sort -u > $MFBENCH_PROFDIR/env.omp

  elif [ "$mfb" == "on" ]; then
    #:settings:on: Activate current profile environment

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
    #:settings:off: Turn off current profile environment

    set -a; source $MFBENCH_PROFDIR/restore.profile; set +a

    for fpvar in $(env | fgrep -e MFBENCH_ -e OMP_ -e KMP_ | fgrep -v _GRIBPACK | cut -f1 -d "="); do
      unset $fpvar
    done

  elif [ "$mfb" == "root" ]; then
    #:settings:off: Prompt mfbench root directory

    \cd $MFBENCH_ROOT
    pwd

  elif [ "$mfb" == "profiles" ]; then
    #:settings:off: List defined profiles with main parameters

    \cd $MFBENCH_STORE
    for this_prof in $(\ls -1d profile_* | cut -d "_" -f 2 | sort -u); do
      printf "%-16s %s\n" $this_prof "$(mfbench_shortview $this_prof)"
    done

  elif [ "$mfb" == "clone" ]; then
    #:settings:clone [prof-name]: Clone current profile to [prof-name]

    if [ $# -ne 1 ]; then
      echo "Usage: mfb $mfb new-profile-name" >&2
      exit 1
    fi

    \rm -rf $MFBENCH_STORE/profile_$1
    \cp -r $MFBENCH_PROFDIR $MFBENCH_STORE/profile_$1

    \cd $MFBENCH_CONF
    for link_select in $(\ls -1 *-SELECT.$MFBENCH_PROFILE 2>/dev/null); do
      base_select=$(basename $link_select .$MFBENCH_PROFILE)
      real_select=$(basename $(readlink -f $link_select))
      echo "Duplicate $base_select"
      \ln -s $real_select $base_select.$1
    done

    export MFBENCH_PROFILE=$1
    export MFBENCH_PROFDIR=$MFBENCH_STORE/profile_$MFBENCH_PROFILE
    echo "MFBENCH_PROFILE=$MFBENCH_PROFILE" > $HOME/.mfb_profile
    echo "Active profile is '$MFBENCH_PROFILE'"
    set -- setenv

  elif [ "$mfb" == "switch" ]; then
    #:settings:switch [prof-name]: Switch to profile [prof-name]

    if [ $# -ne 1 ]; then
      echo "Usage: mfb $mfb new-profile-name" >&2
      exit 1
    fi

    if [ ! -d $MFBENCH_STORE/profile_$1 ]; then
      echo "The specified profile '$1' does not exist" >&2
      exit 1
    fi

    if [ "$MFBENCH_PROFILE" == "$1" ]; then
      echo "Current profile is already '$1'"
    else
      export MFBENCH_PROFILE=$1
      echo "MFBENCH_PROFILE=$MFBENCH_PROFILE" > $HOME/.mfb_profile
      echo "Active profile is '$MFBENCH_PROFILE'"
    fi

    set --

  elif [ "$mfb" == "rmprof" ]; then
    #:settings:rmprof [prof-name]: Remove profile [prof-name]

    if [ $# -ne 1 ]; then
      echo "Usage: mfb $mfb new-profile-name" >&2
      exit 1
    fi

    this_prof=$1
    shift

    if [ "$this_prof" == "$MFBENCH_PROFILE" ]; then
      echo "Could not remove currently active profile" >&2
      exit 1
    fi

    if [ -d $MFBENCH_STORE/profile_$this_prof ]; then
      echo "Removing $MFBENCH_STORE/profile_$this_prof"
      \rm -rf $MFBENCH_STORE/profile_$this_prof
    else
      echo "Profile '$this_prof' does not exist" >&2
      exit 1
    fi

    \cd $MFBENCH_CONF
    for link_select in $(\ls -1 *-SELECT.$this_prof 2>/dev/null); do
      echo "Removing $link_select"
      \rm -f $link_select
    done

  elif [ "$mfb" == "methods" ]; then
    #:execution:methods: Display default execution methods

    echo ${MFBENCH_METHODS:-$(cat $MFBENCH_CONF/mfbench-methods-$MFBENCH_PCUNIT)}

  elif [ "$mfb" == "profdir" ]; then
    #:settings:profdir: Display current profile contents

    \cd $MFBENCH_PROFDIR
    pwd
    \ls -l

  elif [ "$mfb" == "cycle" ]; then
    #:settings:cycle: Display current default cycle

    this_cycle=${MFBENCH_CYCLE:-$(cat $MFBENCH_CONF/gmkpack-cycle)}
    this_cycle=${this_cycle,,}
    this_cycle=${this_cycle//cy/}
    echo "cy$this_cycle"

  elif [ "$mfb" == "float" ]; then
    #:settings:float: Display floating point precision

    this_float=${MFBENCH_FLOAT:-$(cat $MFBENCH_CONF/gmkpack-float)}
    echo "${this_float,,}"

  elif [ "$mfb" == "path" ]; then
    #:settings:path: Display current PATH value

    echo "PATH=$PATH"

  elif [ "$mfb" == "env" ]; then
    #:settings:env: Display MFBENCH environment variables

    env | fgrep MFBENCH_ | fgrep -v MFBENCH_OP_ | sort

  elif [ "$mfb" == "var" ]; then
    #:settings:var: Display specified MFBENCH environment variables

    while [[ $# -gt 0 ]]; do
      varname="MFBENCH_${1^^}"
      varname="${varname//\//_}"
      shift
      if [ "${!varname}" == "" ]; then
        echo "Variable $varname is not set"
      else
        echo "$varname=${!varname}"
      fi
    done

  elif [ "$mfb" == "get" ]; then
    #:settings:get: Retrieve specified MFBENCH environment variables values

    while [[ $# -gt 0 ]]; do
      varname="MFBENCH_${1^^}"
      shift
      if [ "${!varname}" != "" ]; then
        echo "${!varname}"
      fi
    done

  elif [ "$mfb" == "set" ]; then
    #:settings:set [varname] [value]: Set specified MFBENCH environment variable to value

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
    #:settings:unset: Unset specified MFBENCH environment variables

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
    #:settings:omp: Display OpenMP environment variables

    env | fgrep -e OMP_ -e KMP_ | sort

  elif [ "$mfb" == "gmk" ]; then
    #:compile:gmk: Display gmkpack environment variables

    env | fgrep -e GMK -e HOMEPACK -e ROOTPACK -e HOMEBIN -e ROOTBIN | sort

  elif [ "$mfb" == "gmkfile" ]; then
    #:compile:gmkfile [num]: List or select a gmkfile in position [num]

    [[ "$MFBENCH_FUNCTIONS_DIRECTORIES" != "true" ]] && source $MFBENCH_SCRIPTS_FUNCTIONS/directories.sh

    if [[ $# -gt 0 && $1 =~ $isnumber ]]; then
      inum=$1
      shift
    fi

    mfbench_listdir_def conf/gmkfile $inum

  elif [ "$mfb" == "gmkfile-auto" ]; then
    #:compile:gmkfile-auto: Automaticaly select a gmkfile according to ARCH and OPTS

    \cd $MFBENCH_CONF
    \rm -f GMKFILE-SELECT.$MFBENCH_PROFILE
    echo "Select 'gmkfile-$MFBENCH_ARCH.$MFBENCH_OPTS' as default gmkfile"
    \ln -s gmkfile-$MFBENCH_ARCH.$MFBENCH_OPTS GMKFILE-SELECT.$MFBENCH_PROFILE

  elif [ "$mfb" == "sources" ]; then
    #:install:sources [+- tarfile]:List, add or delete from sources directory

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
      set -- list sources $*
    fi

  elif [ "$mfb" == "list" ]; then
    #:settings:list [items]: Ordered list of directories contents

    [[ "$MFBENCH_FUNCTIONS_DIRECTORIES" != "true" ]] && source $MFBENCH_SCRIPTS_FUNCTIONS/directories.sh

    if [ $# -eq 0 ]; then
      set -- all
    fi

    while [[ $# -gt 0 ]]; do
      if [ "$1" == "all" ]; then
        shift
        set -- pack jobs conf inputs outputs references sources install scripts/functions scripts/wrappers $*
        continue
      fi
      mfbench_listdir $1
      if [[ $? == 0 ]]; then
        shift
      else
        echo "Unable to list this directory" >&2
        exit 1
      fi
    done

  elif [ "$mfb" == "fypp" ]; then
    #:install:fypp: Check current Fypp version

    fypp_command=$(which fypp 2>/dev/null)
    if [ $? == 0 ]; then
      fypp_version=$(fypp --version | cut -d " " -f2)
      echo "$fypp_command is $fypp_version"
    else
      echo "*** Fypp is not available, please install ***" >&2
    fi

  elif [ "$mfb" == "cmake" ]; then
    #:install:cmake: Check current CMake version

    cmake_version=$(cmake --version | head -1 | cut -d " " -f3)
    echo "$(which cmake) is $cmake_version"
    if [[ $(echo $cmake_version|cut -d "." -f1) -eq 2 && $(echo $cmake_version|cut -d "." -f2) -lt 16 ]]; then
      echo "*** CMake is too old, please install new version ***" >&2
    fi

  elif [ "$mfb" == "perl" ]; then
    #:install:perl: Check current Perl version

    perl_version=$(perl -we 'print substr($^V,1);')
    echo "$(which perl) is $perl_version"
    if [ $(echo $perl_version | cut -d "." -f2) -lt 026 ]; then
      echo "*** Perl is too old, please install new version ***" >&2
    fi

  elif [ "$mfb" == "yaml" ]; then
    #:install:yaml: Check current YAML version

    yaml_version=$(python3 -c "import yaml; print(yaml.__version__)" 2>/dev/null)
    if [ $? == 0 ]; then
      yaml_module=$(python3 -c "import os, yaml; print(os.path.dirname(yaml.__file__))")
      echo "$yaml_module is $yaml_version"
    else
      echo "*** Python module yaml is not available, please install ***"
    fi

  elif [ "$mfb" == "python" ]; then
    #:install:python: Check current Python version

    python_version=$(python3 --version | cut -d " " -f2)
    echo "$(which python3) is $python_version"
    echo "PYTHONPATH=$PYTHONPATH"

  elif [ "$mfb" == "check" ]; then
    #:install:check: Check version of all external tools

    set -- cmake fypp perl yaml python $*

  elif [ "$mfb" == "bundle-list" ]; then
    #:install:bundle-list: Display the list of all bundle families

    exec bundle.py --list

  elif [ "$mfb" == "bundle-flat" ]; then
    #:install:bundle-flat: Display a flat list of all bundle items

    exec bundle.py --flat

  elif [ "$mfb" == "bundle-arch" ]; then
    #:install:bundle-arch: Display a list of all bundle items with arch and pack options

    exec bundle.py --arch | sort -u

  elif [ "$mfb" == "bundle-map" ]; then
    #:install:bundle-map: Display all defined bundle items per families

    exec bundle.py --cmap

  elif [ "$mfb" == "bundle-item" ]; then
    #:install:bundle-item [item]: Display install variables for a bundle item

    exec bundle.py --item $1

  elif [ "$mfb" == "bundle" ]; then
    #:install:bundle [num]: List or select a bundle file in position [num]

    [[ "$MFBENCH_FUNCTIONS_DIRECTORIES" != "true" ]] && source $MFBENCH_SCRIPTS_FUNCTIONS/directories.sh

    if [[ $# -gt 0 && $1 =~ $isnumber ]]; then
      inum=$1
      shift
    fi

    mfbench_listdir_def conf/bundle $inum

  elif [ "$mfb" == "bundle-auto" ]; then
    #:installl:bundle-auto: Automaticaly select a bundle file according to PCUNIT

    \cd $MFBENCH_CONF
    \rm -f BUNDLE-SELECT.$MFBENCH_PROFILE
    echo "Select 'bundle-${MFBENCH_PCUNIT}pack.yml' as default bundle"
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

      [[ "$MFBENCH_FUNCTIONS_INSTALLS" != "true" ]] && source $MFBENCH_SCRIPTS_FUNCTIONS/installs.sh

      if [ ! -d $MFBENCH_INSTALL_TARGET ]; then
        echo "Creating directory $MFBENCH_INSTALL_TARGET"
        \mkdir -p $MFBENCH_INSTALL_TARGET
      fi

      if [ "$MFBENCH_INSTALL_MKARCH"  == "yes" ]; then
        if [ ! -d "$MFBENCH_INSTALL/$MFBENCH_ARCH/lib" ]; then
          echo "Creating directory $MFBENCH_INSTALL/$MFBENCH_ARCH/lib"
          \mkdir -p $MFBENCH_INSTALL/$MFBENCH_ARCH/lib
        fi
        if [ ! -d "$MFBENCH_INSTALL/$MFBENCH_ARCH/lib64" ]; then
          echo "Link directory $MFBENCH_INSTALL/$MFBENCH_ARCH/lib64"
          \cd $MFBENCH_INSTALL/$MFBENCH_ARCH
          \ln -s lib  lib64
        fi
      fi

      if [ "$MFBENCH_INSTALL_MKARCH"  == "yes" ]; then
        source $MFBENCH_SCRIPTS_WRAPPERS/export_compilers.sh
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
     #:install:install [items]: Install specified items

    set -- process install $*

  elif [ "$mfb" == "uninstall" ]; then
    #:install:uninstall [items]: Uninstall specified items

    set -- process uninstall $*

  elif [ "$mfb" == "installed" ]; then
    #:install:installed: List installed items

    \cd $MFBENCH_TRACKDIR
    \ls -1 track.*.shared track.*.$MFBENCH_ARCH 2>/dev/null | sort -u | cut -f2 -d "."

  elif [ "$mfb" == "track" ]; then
    #:install:track [items]: List local installed files for [items]

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
    #:compile:pack: Display active pack

    mandatory_var_msg "'$mfb'" packs

    if [ "$MFBENCH_PACK" == "" ]; then
      previous_pack=${MFBENCH_LASTPACK:-$MFBENCH_MAINPACK}
      mandatory_var_raw arch opts
      if [ "$previous_pack" = "" ]; then
        this_cycle=${MFBENCH_CYCLE:-$(cat $MFBENCH_CONF/gmkpack-cycle)}
        this_branch=${MFBENCH_BRANCH:-rapsmain}
        this_packid=${MFBENCH_PACKID:-01}
      else
        this_cycle=$(echo $previous_pack | cut -d "." -f1 | cut -d "_" -f1)
        this_branch=$(echo $previous_pack | cut -d "." -f1 | cut -d "_" -f2)
        this_packid=$(echo $previous_pack | cut -d "." -f2)
      fi
      echo "$MFBENCH_PACKS/${this_cycle}_${this_branch}.$this_packid.$MFBENCH_ARCH.$MFBENCH_OPTS"
    else
      echo "$MFBENCH_PACKS/$MFBENCH_PACK"
    fi

  elif [ "$mfb" == "nest" ]; then
    #:compile:nest: Set the current pack as default one

    mandatory_var_msg "'$mfb'" packs

    this_root=$(dirname $PWD)
    this_pack=$(basename $PWD)

    if [ "$this_root" != "$MFBENCH_PACKS" ]; then
      echo "This is not a proper location for a pack" >&2
      exit 1
    fi

    export MFBENCH_PACK=$this_pack
    \ls src/main 2>/dev/null
    if [ $? -eq 0 ]; then
      export MFBENCH_LASTPACK=$this_pack
    else
      unset MFBENCH_LASTPACK
      export MFBENCH_MAINPACK=$this_pack
    fi

    set -- setenv

  elif [ "$mfb" == "mkmain" ]; then
    #:compile:mkmain [branch] [id]: Build a ground pack with optional settings

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

    \rm -f $MFBENCH_SUPPORT/arch/*.$MFBENCH_ARCH.$MFBENCH_OPTS
    \cp $(realpath $MFBENCH_CONF/GMKFILE-SELECT.$MFBENCH_PROFILE) $MFBENCH_SUPPORT/arch/

    echo "Creating base pack $MFBENCH_PACK"
    [[ "$tempo_fake" == "true" ]] && continue

    gmkpack \
      -r $this_cycle  \
      -b $this_branch \
      -n $this_packid \
      -l $MFBENCH_ARCH -o $MFBENCH_OPTS -a -K -p $(cat $MFBENCH_CONF/gmkpack-binaries-$MFBENCH_PCUNIT)

    if [ $? -ne 0 ]; then
      echo "Could not complete '$mfb'" >&2
      exit 1
    fi

    export MFBENCH_MAINPACK=$MFBENCH_PACK

    if [ "$MFBENCH_AUTOPACK" == "yes" ]; then
      set -- setenv postpack install $(bundle.py --type hub) $(bundle.py --type main)
    else
      set -- setenv postpack
    fi

  elif [ "$mfb" == "mkpack" ]; then
    #:compile:mkpack [branch] [id]: Build a derivated pack with optional settings

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

    echo "Creating dev pack $MFBENCH_PACK"
    [[ "$tempo_fake" == "true" ]] && continue

    gmkpack \
      -r $main_cycle  \
      -b $base_branch \
      -u $this_branch \
      -n $this_packid \
      -v $base_packid \
      -l $MFBENCH_ARCH -o $MFBENCH_OPTS -p $(cat $MFBENCH_CONF/gmkpack-binaries-$MFBENCH_PCUNIT)

    export MFBENCH_LASTPACK=$MFBENCH_PACK
    set -- setenv postpack

  elif [ "$mfb" == "postpack" ]; then
    #:compile:postpack: Rerun methods called after pack creation (mostly internal)

    mandatory_var_raw packs pack conf

    [[ "$MFBENCH_FUNCTIONS_COMPILE" != "true" ]] && source $MFBENCH_SCRIPTS_FUNCTIONS/compile.sh

    \cd $MFBENCH_PACKS/$MFBENCH_PACK
    for compile_func in $(declare -F | fgrep mfbench_compile_ | cut -d " " -f3 | sort -u); do
      echo "Apply function $compile_func..."
      $compile_func
    done

  elif [ "$mfb" == "rmpack [packs]" ]; then
    #:compile:rmpack [pack]: Remove specified [pack]

    mandatory_var_raw packs

    if [ $# -gt 0 ]; then
      this_pack=$1
      shift
    else
      mandatory_var_raw pack
      this_pack=$MFBENCH_PACK
    fi

    echo "Removing $this_pack..."
    [[ "$tempo_fake" == "true" ]] && continue

    \cd $MFBENCH_PACKS
    \rm -rf $this_pack

    [[ "$this_pack" == "$MFBENCH_LASTPACK" ]] && unset MFBENCH_LASTPACK
    [[ "$this_pack" == "$MFBENCH_MAINPACK" ]] && unset MFBENCH_MAINPACK

    unset MFBENCH_PACK

    set -- setenv

  elif [ "$mfb" == "compilers" ]; then
    #:compile:compilers: Display and export compilers wrappers

    source $MFBENCH_SCRIPTS_WRAPPERS/export_compilers.sh

  elif [ "$mfb" == "build" ]; then

    check_private
    mandatory_var_raw packs
    \cd $MFBENCH_PACKS

    if [ "$MFBENCH_PACK" == "" ]; then
      mandatory_var_raw arch opts
      export MFBENCH_PACK=$(\ls -tr1d *.*.$MFBENCH_ARCH.$MFBENCH_OPTS | tail -1)
    fi

    [[ "$MFBENCH_FUNCTIONS_COMPILE" != "true" ]] && source $MFBENCH_SCRIPTS_FUNCTIONS/compile.sh

    source $MFBENCH_SCRIPTS_WRAPPERS/export_compilers.sh

    \cd $MFBENCH_PACKS/$MFBENCH_PACK
    pwd

    build_prefix=$1
    shift

    [[ $# -eq 0 ]] && set -- $(cat $MFBENCH_CONF/gmkpack-packages $MFBENCH_CONF/gmkpack-binaries-$MFBENCH_PCUNIT)

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

    if [[ "$MFBENCH_RMBUILD" == "yes"  && -d hub/local/build ]]; then
      echo "Removing build directory '$PWD/hub/local/build'"
      \rm -rf hub/local/build
    fi

    if [ "$MFBENCH_PCUNIT" = "gpu" ]; then
      echo "Creating 'parallelmethod' files"
      $MFBENCH_SCRIPTS/tools/parallelmethod.pl
    fi

  elif [ "$mfb" == "compile" ]; then
    #:compile:compile [ics]: Compile through all or specified ics files in the current pack

    tempo_private=true
    set -- build ics $*

  elif [ "$mfb" == "load" ]; then
    #:compile:load [ild]: Load through all or specified ild files in the current pack

    tempo_private=true
    set -- build ild $*

  elif [ "$mfb" == "clean" ]; then
   #:compile:clean: Clean current pack

    mandatory_var_raw packs pack
    \cd $MFBENCH_PACKS/$MFBENCH_PACK
    cleanpack
    resetpack

  elif [ "$mfb" == "stamp" ]; then
    #:settings:stamp: Get a time stamp

    echo $(date '+D%Y%m%d_T%H%M%S')$(date '+%N' | cut -c 1-2)

  elif [ "$mfb" == "inputs" ]; then
    #:execution:inputs: Ordered list of input sets

    set -- list inputs $*

  elif [ "$mfb" == "namelists" ]; then
    #:execution:namelists: Ordered list of namelists

    set -- list namelists $*

  elif [ "$mfb" == "play" ]; then
    #:execution:play [jobs]: Execute specified [jobs] in the current environment

    \cd $MFBENCH_JOBS

    while [[ $# -gt 0 ]]; do
      this_play=$1
      shift
      echo "Playing '$this_play.sh'"
      echo "Warning: this feature is not yet fully implemented"
      # Should fix first a running environment and submit method
      exec ./$this_play.sh
    done

  elif [ "$mfb" == "outputs" ]; then
    #:execution:outputs: Ordered list of output sets

    set -- list outputs $*

  elif [ "$mfb" == "tube" ]; then
    #:execution:tube: Execute shell commands through the MFBENCH settings

    exec $*
    set --

  elif [ "$mfb" == "mkrundir" ]; then
    #:execution:mkrundir: Create an execution directory

    export MFBENCH_RUNDIR=$MFBENCH_TMPDIR/$(basename $(mktemp -u))
    [[ ! -d $MFBENCH_RUNDIR ]] && \mkdir -p $MFBENCH_RUNDIR
    echo $MFBENCH_RUNDIR
    set -- setenv

  else

    varname="MFBENCH_${mfb^^}"
    varname="${varname//\//_}"
    if [ "${!varname}" == "" ]; then
      echo "Warning: subcommand '$mfb' not found" >&2
      exit 1
    else
      echo "${!varname}"
    fi

 fi

done
