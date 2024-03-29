#!/bin/bash

export MFBENCH_FUNCTIONS_INSTALLS=true

function mfbench_install_track_in
{
  \cd $MFBENCH_INSTALL_TARGET
  find * -type f -print | sort > $MFBENCH_TMPDIR/mfbench.track.$1.list1
}

function mfbench_install_track_out
{
  \cd $MFBENCH_INSTALL_TARGET
  find * -type f -print | sort > $MFBENCH_TMPDIR/mfbench.track.$1.list2
  comm -3 $MFBENCH_TMPDIR/mfbench.track.$1.list1 $MFBENCH_TMPDIR/mfbench.track.$1.list2 | sed 's/\t//g' > $MFBENCH_TRACKDIR/track.$1.$MFBENCH_INSTALL_TRACKEXT
  \rm -f $MFBENCH_TMPDIR/mfbench.track.$1.list1 $MFBENCH_TMPDIR/mfbench.track.$1.list2
}

function mfbench_uninstall_track_in
{
  if [ -f "$MFBENCH_TRACKDIR/track.$1.$MFBENCH_INSTALL_TRACKEXT" ]; then
    echo "Install was recorded in $MFBENCH_TRACKDIR/track.$1.$MFBENCH_INSTALL_TRACKEXT"
  fi
}

function mfbench_uninstall_track_out
{
  if [ -f "$MFBENCH_TRACKDIR/track.$1.$MFBENCH_INSTALL_TRACKEXT" ]; then
    \cd $MFBENCH_INSTALL_TARGET
    local this_file
    for this_file in $(< $MFBENCH_TRACKDIR/track.$1.$MFBENCH_INSTALL_TRACKEXT); do
      if [ -f $this_file ]; then
        echo "Removing file $this_file"
        \rm -f $this_file
      fi
    done
    echo "Removing track file $MFBENCH_TRACKDIR/track.$1.$MFBENCH_INSTALL_TRACKEXT"
    \rm -f $MFBENCH_TRACKDIR/track.$1.$MFBENCH_INSTALL_TRACKEXT
  fi
}

function mfbench_set_env
{
  local this_name=$1
  shift
  \rm -f $MFBENCH_PROFDIR/env.install.$this_name
  touch $MFBENCH_PROFDIR/env.install.$this_name
  local this_var
  for this_var in $*; do
    echo "$this_var=${!this_var}" >> $MFBENCH_PROFDIR/env.install.$this_name
  done
}

function mfbench_set_path
{
  local this_name=$1
  local this_path=$2
  if [[ ":$PATH:" == *":$this_path:"* ]]; then
    echo "PATH for '$this_name' already set"
  else
    export PATH=$this_path:$PATH
    echo "PATH=$this_path:\$PATH" > $MFBENCH_PROFDIR/path.install.$this_name
  fi
}

function mfbench_set_python
{
  local this_name=$1
  local this_path=$2
  if [[ ":$PYTHONPATH:" == *":$this_path:"* ]]; then
    echo "PYTHONPATH for '$this_name' already set"
  else
    export PYTHONPATH=$this_path:$PYTHONPATH
    echo "PYTHONPATH=$this_path:\$PYTHONPATH" > $MFBENCH_PROFDIR/python.install.$this_name
  fi
}

# ------------------------------------------------------------------------------
# INSTALL

function mfbench_install_from_archive
{
  \cd $MFBENCH_BUILD
  if [ -d $MFBENCH_INSTALL_TOPDIR ]; then
    echo "Source already inflated: $MFBENCH_INSTALL_TOPDIR"
  else
    if [ -f $MFBENCH_SOURCES/$MFBENCH_INSTALL_SOURCE ]; then
      echo "Create $MFBENCH_INSTALL_TOPDIR"
      tar xvf $MFBENCH_SOURCES/$MFBENCH_INSTALL_SOURCE
    else
      echo "Could note find archive $MFBENCH_SOURCES/$MFBENCH_INSTALL_SOURCE" >&2
      exit 1
    fi
  fi
}

function mfbench_install_from_git
{
  \cd $MFBENCH_INSTALL_TARGET
  local git_select
  if [ "$MFBENCH_INSTALL_VERSION" == "" ]; then
    git_select=''
  else
    git_select="--branch $MFBENCH_INSTALL_VERSION"
  fi
  git clone $git_select $MFBENCH_INSTALL_GIT $MFBENCH_INSTALL_NAME
}

function mfbench_install_with_gitpack
{
  \cd $MFBENCH_INSTALL_TARGET
  local git_select
  if [ "$MFBENCH_INSTALL_VERSION" == "" ]; then
    git_select=''
  else
    git_select="--branch $MFBENCH_INSTALL_VERSION"
  fi
  gitpack --init --repository $MFBENCH_INSTALL_GIT $git_select
}

function mfbench_install_generic
{
  if [[ "$MFBENCH_INSTALL_TYPE" != "tools" && "$MFBENCH_ARCH" == "" ]]; then
    echo "Variable MFBENCH_ARCH is mandatory for type [$MFBENCH_INSTALL_TYPE]" >&2
    exit 1
  fi

  if [ -d $MFBENCH_INSTALL_TARGET/$MFBENCH_INSTALL_NAME ]; then
    echo "Install $MFBENCH_INSTALL_NAME already done ?"
  else
    if [[ "$MFBENCH_INSTALL_GIT" == "" ]]; then
      echo "Install from archive $MFBENCH_INSTALL_SOURCE"
      mfbench_install_from_archive
    elif [[ "$MFBENCH_INSTALL_VIMPACK" == "yes" ]]; then
      echo "Install from repository $MFBENCH_INSTALL_GIT (gitpack)"
      mfbench_install_with_gitpack
    else
      echo "Install from repository $MFBENCH_INSTALL_GIT (clone)"
      mfbench_install_from_git
    fi
  fi
}

# ------------------------------------------------------------------------------
# TYPE INSTALL FUNCTIONS

function mfbench_install_dummies
{
  \cd $MFBENCH_BUILD
  bundle.py --load $MFBENCH_INSTALL_NAME | tee bundle_load.$MFBENCH_INSTALL_NAME.log
  local this_src=$(head -1 bundle_load.$MFBENCH_INSTALL_NAME.log)
  if [ -f "$this_src" ]; then
    $MFBENCH_COMPILER_CC -c $this_src
    ar crv $MFBENCH_INSTALL_TARGET/$(basename $this_src .c).a $(basename $this_src .c).o
  else
    echo "Could not generate dummy source file for '$MFBENCH_INSTALL_NAME'" >&2
    exit 1
  fi
}

function mfbench_uninstall_dummies
{
  \cd $MFBENCH_BUILD
  if [ -f bundle_load.$MFBENCH_INSTALL_NAME.log ]; then
    local this_src=$(head -1 bundle_load.$MFBENCH_INSTALL_NAME.log)
    echo "Removing bundle_load.$MFBENCH_INSTALL_NAME.log"
    \rm -f bundle_load.$MFBENCH_INSTALL_NAME.log
    local this_file
    for this_file in $this_src $(basename $this_src .c).o $MFBENCH_INSTALL_TARGET/$(basename $this_src .c).a; do
      if [ -f "$this_file" ]; then
        echo "Removing $this_file"
        \rm -f $this_file
      fi
    done
  fi
}

# ------------------------------------------------------------------------------
# SPECIFIC INSTALL OR POST INSTALL FUNCTIONS

function mfbench_install_yaml
{
  if [ -d "$MFBENCH_INSTALL/tools/yaml" ]; then
    echo "Install yaml already done ?"
  else
    git clone https://github.com/yaml/pyyaml.git $MFBENCH_INSTALL/tools/yaml
  fi
}

function mfbench_post_install_fypp
{
  mfbench_set_path fypp $MFBENCH_INSTALL_TARGET/$MFBENCH_INSTALL_NAME/bin
}

function mfbench_post_install_vimpack
{
  mfbench_set_path vimpack $MFBENCH_INSTALL_TARGET/$MFBENCH_INSTALL_NAME
}

function mfbench_post_install_yaml
{
  mfbench_set_python yaml $MFBENCH_INSTALL/tools/yaml/lib
}

function mfbench_post_install_cmake
{
  if [ -d $MFBENCH_BUILD/$MFBENCH_INSTALL_TOPDIR ]; then
    \cd $MFBENCH_BUILD/$MFBENCH_INSTALL_TOPDIR
    ./configure --prefix=$MFBENCH_INSTALL_TARGET/$MFBENCH_INSTALL_NAME
    make -j$MFBENCH_INSTALL_THREADS install
    [[ $? -eq 0 ]] && mfbench_set_path cmake $MFBENCH_INSTALL_TARGET/$MFBENCH_INSTALL_NAME/bin
  fi
}

function mfbench_post_install_perl
{
  if [ -d $MFBENCH_BUILD/$MFBENCH_INSTALL_TOPDIR ]; then
    \cd $MFBENCH_BUILD/$MFBENCH_INSTALL_TOPDIR
    set -e
    ./Configure -des -D usethreads -D prefix=$MFBENCH_INSTALL_TARGET/$MFBENCH_INSTALL_NAME
    make -j$MFBENCH_INSTALL_THREADS install
    set +e
    [[ $? -eq 0 ]] && mfbench_set_path perl $MFBENCH_INSTALL_TARGET/$MFBENCH_INSTALL_NAME/bin
  fi
}

function mfbench_post_install_fftw_sp
{
  if [ -d $MFBENCH_BUILD/$MFBENCH_INSTALL_TOPDIR ]; then
    \cd $MFBENCH_BUILD/$MFBENCH_INSTALL_TOPDIR
    set -e
    ./configure --prefix=$MFBENCH_INSTALL_TARGET --enable-fortran --enable-single
    make
    make install
    set +e
  fi
}

function mfbench_post_install_fftw_dp
{
  if [ -d $MFBENCH_BUILD/$MFBENCH_INSTALL_TOPDIR ]; then
    \cd $MFBENCH_BUILD/$MFBENCH_INSTALL_TOPDIR
    set -e
    ./configure --prefix=$MFBENCH_INSTALL_TARGET --enable-fortran
    make
    make install
    set +e
  fi
}

function mfbench_post_install_generic_build
{
  if [ -d $MFBENCH_BUILD/$MFBENCH_INSTALL_TOPDIR ]; then
    \cd $MFBENCH_BUILD
    this_build="$MFBENCH_INSTALL_NAME-$MFBENCH_INSTALL_VERSION-Build"
    \rm -rf $this_build
    mkdir -p $this_build
    \cd $this_build
    cmake ../$MFBENCH_INSTALL_TOPDIR -DCMAKE_INSTALL_PREFIX=$MFBENCH_INSTALL_TARGET $*
    make -j$MFBENCH_INSTALL_THREADS install
    \rm -rf $this_build
  fi
}

function mfbench_post_install_eccodes
{
  mfbench_post_install_generic_build -DENABLE_ECCODES_THREADS=1 -DENABLE_JPG=0 -DENABLE_AEC=OFF
}

function mfbench_post_install_hdf5
{
  mfbench_post_install_generic_build -DHDF5_ENABLE_Z_LIB_SUPPORT=ON -DHDF5_BUILD_FORTRAN=ON
}

function mfbench_post_install_netcdf_c
{
  mfbench_post_install_generic_build
}

function mfbench_post_install_netcdf_fortran
{
  [[ "$MFBENCH_ARCH" == *"GNU"* ]] && export FFLAGS="-fallow-argument-mismatch"
  mfbench_post_install_generic_build
}

function mfbench_post_install_lapack
{
  mfbench_post_install_generic_build -DBUILD_SHARED_LIBS=ON
}

function mfbench_post_install_eigen
{
  mfbench_post_install_generic_build -DBUILD_SHARED_LIBS=ON
}

function mfbench_post_install_gmkpack
{
  if [ -d $MFBENCH_BUILD/$MFBENCH_INSTALL_TOPDIR ]; then
    \mv $MFBENCH_BUILD/$MFBENCH_INSTALL_TOPDIR $MFBENCH_INSTALL_TARGET
    \cd $MFBENCH_INSTALL_TARGET/$MFBENCH_INSTALL_TOPDIR
    export GMKTMP=$MFBENCH_TMPDIR
    export GMK_SUPPORT=$MFBENCH_TMPDIR/gmkpack_support
    ./build_gmkpack << EOF
n
EOF
    if [ ! -d $MFBENCH_SUPPORT/link ]; then
      echo "Creating directory $MFBENCH_SUPPORT/link"
      \mkdir -p $MFBENCH_SUPPORT/link
    fi
    local binconf
    for binconf in $(< $MFBENCH_CONF/gmkpack-binaries-$MFBENCH_PCUNIT); do
      if [ -d $MFBENCH_SUPPORT/link/$binconf ]; then
        echo "Warning: link specifications for '$binconf' already defined" >&2
      else
        if [ -d link/$binconf ]; then
          \cp -r link/$binconf $MFBENCH_SUPPORT/link/
        else
          echo "Warning: link specifications for '$binconf' does not exist" >&2
        fi
      fi
    done

    export GMK_SUPPORT=$MFBENCH_SUPPORT
    export GMKFILE='gmkfile-$MFBENCH_ARCH'
    export GMKROOT=$MFBENCH_INSTALL_TARGET/$MFBENCH_INSTALL_NAME
    export ROOTPACK=$MFBENCH_PACKS
    export HOMEPACK=$MFBENCH_PACKS
    export ROOTBIN=$MFBENCH_PACKS
    export HOMEBIN=$MFBENCH_PACKS
    export HOMELIB=$MFBENCH_PACKS
    mfbench_set_path gmkpack $GMKROOT/util
    mfbench_set_env  gmkpack GMKROOT GMKFILE GMK_SUPPORT ROOTPACK HOMEPACK ROOTBIN HOMEBIN HOMELIB
    export GMKFILE="gmkfile-$MFBENCH_ARCH"
  fi
}

function mfbench_post_install_ial
{
  [[ ! -d $MFBENCH_INSTALL_TARGET ]] && \mkdir -p $MFBENCH_INSTALL_TARGET

  local this_name=$(basename $MFBENCH_INSTALL_TARGET)
  \cd $(dirname $MFBENCH_INSTALL_TARGET)

  if [[ "$MFBENCH_INSTALL_VIMPACK" == "yes" ]]; then
    echo "Post install with gitpack is clear"
  elif [[ "$MFBENCH_INSTALL_GIT" == "" ]]; then
    echo "Move $MFBENCH_BUILD/$MFBENCH_INSTALL_TOPDIR as $MFBENCH_INSTALL_TARGET"
    \rm -rf $this_name
    \mv $MFBENCH_BUILD/$MFBENCH_INSTALL_TOPDIR $this_name
  else
    echo "Move $this_name/$MFBENCH_INSTALL_NAME as $this_name"
    \mv $this_name/$MFBENCH_INSTALL_NAME .
    \rmdir $this_name
    \mv $MFBENCH_INSTALL_NAME $this_name
  fi
}

# ------------------------------------------------------------------------------
# UNINSTALL

function mfbench_uninstall_generic
{
  local this_dir
  for this_dir in $(\ls -1d $MFBENCH_BUILD/$MFBENCH_INSTALL_TOPDIR* 2>/dev/null); do
    echo "Removing directory $this_dir"
    \rm -rf $this_dir
  done
  if [ -d "$MFBENCH_INSTALL_TARGET/$MFBENCH_INSTALL_TOPDIR" ]; then
    echo "Removing directory $MFBENCH_INSTALL_TARGET/$MFBENCH_INSTALL_TOPDIR"
    \rm -rf $MFBENCH_INSTALL_TARGET/$MFBENCH_INSTALL_TOPDIR
  fi
  if [ -d "$MFBENCH_INSTALL_TARGET/$MFBENCH_INSTALL_NAME" ]; then
    echo "Removing directory $MFBENCH_INSTALL_TARGET/$MFBENCH_INSTALL_NAME"
    \rm -rf $MFBENCH_INSTALL_TARGET/$MFBENCH_INSTALL_NAME
  elif [ -L "$MFBENCH_INSTALL_TARGET/$MFBENCH_INSTALL_NAME" ]; then
    echo "Removing link $MFBENCH_INSTALL_TARGET/$MFBENCH_INSTALL_NAME"
    \rm -f $MFBENCH_INSTALL_TARGET/$MFBENCH_INSTALL_NAME
  fi
  local this_path
  for this_path in $(\ls $MFBENCH_PROFDIR/*.*.$MFBENCH_INSTALL_NAME 2>/dev/null); do
    echo "Removing file $this_path"
    \rm -f $this_path
  done
}
