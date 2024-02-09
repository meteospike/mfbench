#!/bin/bash

# Set up default compilers env variables 

if [ "$MFBENCH_ARCH" == "" ]; then
  echo "Variable MFBENCH_ARCH is not set" >&2
  exit 1
fi

if [ "$MFBENCH_SCRIPTS_WRAPPERS" == "" ]; then
  echo "Variable MFBENCH_SCRIPTS_WRAPPERS is not set" >&2
  exit 1
fi

for compiler in cc cxx f90 mpicc mpicxx mpif90 setup; do
  actual_var="MFBENCH_COMPILER_${compiler^^}"
  export $actual_var="$MFBENCH_SCRIPTS_WRAPPERS/$MFBENCH_ARCH/$compiler"
  echo export $actual_var=${!actual_var}
done

export MFBENCH_COMPILER_INSTALL="$MFBENCH_INSTALL/$MFBENCH_ARCH"
echo export MFBENCH_COMPILER_INSTALL=$MFBENCH_COMPILER_INSTALL

