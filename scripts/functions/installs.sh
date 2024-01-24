#!/bin/bash

export MFBENCH_FUNCTIONS_INSTALLS=true

function mfbench_set_path ()
{
  this_name=$1
  this_path=$2
  if [[ ":$PATH:" == *":$this_path:"* ]]; then
    echo "PATH for '$this_name' already set"
  else
    export PATH=$this_path:$PATH
    echo "PATH=$this_path:\$PATH" > $MFBENCH_STORE/path.install.$this_name.$MFBENCH_PROFILE
  fi
}

function mfbench_set_python ()
{
  this_name=$1
  this_path=$2
  if [[ ":$PYTHONPATH:" == *":$this_path:"* ]]; then
    echo "PYTHONPATH for '$this_name' already set"
  else
    export PYTHONPATH=$this_path:$PYTHONPATH
    echo "PYTHONPATH=$this_path:\$PYTHONPATH" > $MFBENCH_STORE/path.python.$this_name.$MFBENCH_PROFILE
  fi
}

# ------------------------------------------------------------------------------
# INSTALL

function mfbench_install_from_archive ()
{
  \cd $MFBENCH_BUILD
  this_install=$MFBENCH_INSTALL_NAME-$MFBENCH_INSTALL_VERSION

  if [ -d $this_install ]; then
    echo "Source already inflated: $this_install"
  else
    if [ -f $MFBENCH_SOURCES/$MFBENCH_INSTALL_SOURCE ]; then
      echo "Create $this_install"
      tar xvf $MFBENCH_SOURCES/$MFBENCH_INSTALL_SOURCE
    else
      echo "Could note find archive $MFBENCH_SOURCES/$MFBENCH_INSTALL_SOURCE" >&2
      exit 1
    fi
  fi
}

function mfbench_install_from_git ()
{
  \cd $MFBENCH_INSTALL_TARGET
  if [ "$MFBENCH_INSTALL_VERSION" == "" ]; then
    git_select=''
  else
    git_select="--branch $MFBENCH_INSTALL_VERSION"
  fi
  echo git clone $git_select $MFBENCH_INSTALL_GIT $MFBENCH_INSTALL_NAME
  git clone $git_select $MFBENCH_INSTALL_GIT $MFBENCH_INSTALL_NAME
}

function mfbench_install_generic ()
{
  if [[ "$MFBENCH_INSTALL_TYPE" != "tools" && "$MFBENCH_ARCH" == "" ]]; then
    echo "Variable MFBENCH_ARCH is mandatory for type [$MFBENCH_INSTALL_TYPE]" >&2
    exit 1
  fi

  if [ ! -d $MFBENCH_INSTALL_TARGET ]; then
    echo "Creating directory $MFBENCH_INSTALL_TARGET"
    mkdir -p $MFBENCH_INSTALL_TARGET
  fi

  if [ -d $MFBENCH_INSTALL_TARGET/$MFBENCH_INSTALL_NAME ]; then
    echo "Install $MFBENCH_INSTALL_NAME already done ?"
  else
    if [[ "$MFBENCH_INSTALL_GIT" == "" ]]; then
      echo "Install from archive $MFBENCH_INSTALL_SOURCE"
      mfbench_install_from_archive
    else
      echo "Install from repository $MFBENCH_INSTALL_GIT"
      mfbench_install_from_git
    fi
  fi
}

# ------------------------------------------------------------------------------
# SPECIFIC INSTALL OR POST INSTALL FUNCTIONS

function mfbench_install_yaml ()
{
  if [ -d "$MFBENCH_INSTALL/tools/yaml" ]; then
    echo "Install yaml already done ?"
  else
    echo git clone https://github.com/yaml/pyyaml.git $MFBENCH_INSTALL/tools/yaml
    git clone https://github.com/yaml/pyyaml.git $MFBENCH_INSTALL/tools/yaml
  fi
}

function mfbench_post_install_fypp ()
{
  mfbench_set_path fypp $MFBENCH_INSTALL_TARGET/$MFBENCH_INSTALL_NAME/bin
}

function mfbench_post_install_yaml ()
{
  mfbench_set_python yaml $MFBENCH_INSTALL/tools/yaml/lib
}

function mfbench_post_install_cmake ()
{
  this_install=$MFBENCH_INSTALL_NAME-$MFBENCH_INSTALL_VERSION
  if [ -d $MFBENCH_BUILD/$this_install ]; then
    \cd $MFBENCH_BUILD/$this_install
    ./configure --prefix=$MFBENCH_INSTALL_TARGET/$MFBENCH_INSTALL_NAME
    make -j$MFBENCH_MAKE_JOPT install
   [[ $? -eq 0 ]] && mfbench_set_path cmake $MFBENCH_INSTALL_TARGET/$MFBENCH_INSTALL_NAME/bin
  fi
}

function mfbench_post_install_perl ()
{
  this_install=$MFBENCH_INSTALL_NAME-$MFBENCH_INSTALL_VERSION
  if [ -d $MFBENCH_BUILD/$this_install ]; then
    \cd $MFBENCH_BUILD/$this_install
    set -e
    ./Configure -des -D usethreads -D prefix=$MFBENCH_INSTALL_TARGET/$MFBENCH_INSTALL_NAME
    make -j$MFBENCH_MAKE_JOPT install
    set +e
   [[ $? -eq 0 ]] && mfbench_set_path perl $MFBENCH_INSTALL_TARGET/$MFBENCH_INSTALL_NAME/bin
  fi
}

# ------------------------------------------------------------------------------
# UNINSTALL

function mfbench_uninstall_generic ()
{
  if [ "$MFBENCH_INSTALL_TARGET" == "" ]; then
    echo "Install dir not set" >&2
  else
    if [ -d "$MFBENCH_INSTALL_TARGET/$MFBENCH_INSTALL_NAME" ]; then
      echo "Removing $MFBENCH_INSTALL_TARGET/$MFBENCH_INSTALL_NAME"
      \rm -rf $MFBENCH_INSTALL_TARGET/$MFBENCH_INSTALL_NAME
    fi
    for this_path in $(\ls $MFBENCH_STORE/path.*.$MFBENCH_INSTALL_NAME.$MFBENCH_PROFILE 2>/dev/null); do
      echo "Removing file $this_path"
      \rm -f $this_path
    done
  fi
}

