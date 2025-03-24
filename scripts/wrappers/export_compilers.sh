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

for compiler in setup cc cxx ccu f90 mpicc mpicxx mpif90 mpirun; do
  actual_var="MFBENCH_COMPILER_${compiler^^}"
  echo   $actual_var="$MFBENCH_SCRIPTS_WRAPPERS/$MFBENCH_ARCH/$compiler"
  export $actual_var="$MFBENCH_SCRIPTS_WRAPPERS/$MFBENCH_ARCH/$compiler"
done

echo   MFBENCH_COMPILER_INSTALL="$MFBENCH_INSTALL/$MFBENCH_ARCH"
export MFBENCH_COMPILER_INSTALL="$MFBENCH_INSTALL/$MFBENCH_ARCH"

