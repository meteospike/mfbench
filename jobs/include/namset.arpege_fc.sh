#!/bin/bash

# Set various geometry and optimisation in arpege namelist

if [ "$CONFIG_VECTOR" == "on" ] ; then
  # Prefer 1-way MPI distribution by default
  NPRGPNS=$MASTER_NPROC
  NPRGPEW=1
  NPRTRW=$MASTER_NPROC
  NPRTRV=1
  # A reduced value of NSTRIN seems to save memory without impacting the performance
  NSTRIN=$((NPROC/2))
  # Traditional Legendre Transforms are faster on vector engines
  LUSEFLT=.FALSE.
  # Miscellaneous architecture-specific optimizations
  LOPT_SCALAR=.FALSE.
  LEQ_REGIONS=.FALSE.
  # fftw looks less efficient than the traditional fft992
  LFFTW=.FALSE.
  # Vector length (a small value makes more realistic testing at low resolution)
  if [ "$CONFIG_GRID" == "tl0048" ] ; then
    NPROMA=-255
  else
    NPROMA=-1023
  fi
else
  # Prefer default square MPI distribution at low resolution for testing
  NPRGPNS="-"
  NPRGPEW="-"
  NPRTRW="-"
  NPRTRV="-"
  # Number of MPI tasks for traditional I/O decoding
  NSTRIN=$MASTER_NPROC
  # Fast Legendre Transforms (do not work at very low resolution)
  if [ "$CONFIG_GRID" == "tl0048" ]; then
    LUSEFLT=.FALSE.
  else
    LUSEFLT=.TRUE.
  fi
  # Miscellaneous architecture-specific optimizations
  LOPT_SCALAR=.TRUE.
  LEQ_REGIONS=.TRUE.
  # fftw is more efficient than the traditional fft992
  LFFTW=.TRUE.
  # Vector length or cache-blocking factor (a small value to keep data in memory cache)
  NPROMA=-50
fi

# Number of MPI tasks for traditional I/O encoding :
NSTROUT=$MASTER_NPROC

# Stack (1) vs heap (2) allocation in the model gridpoint computations :
NOPT_MEMORY=2

# Stack (1) vs heap (0) allocation in the grid-point MPI transpositions of the spectral transforms :
NSTACK_MEMORY_TR=1

# Set the variable below to .TRUE. to activate a MPI barrier before the semi-lagrangian communications :
LSYNC_SLCOM=.FALSE.

# Set the variable below to .TRUE. to activate a MPI barrier after the semi-lagrangian communications :
LSYNC_POSTSLCOM2=.FALSE.

# Set NPRINTLEV=1 to increase the listing verbosity :
NPRINTLEV="-"

# Perform namelists in-place update
$MFBENCH_SCRIPTS/tools/xpnam --delta="
 &NAMTRANS
   LUSEFLT=${LUSEFLT},
   LFFTW=${LFFTW},
 /
 &NAMPAR0
   NPRINTLEV=${NPRINTLEV},
   LOPT_SCALAR=${LOPT_SCALAR},
   NPROC=${MASTER_NPROC},
   NPRGPNS=${NPRGPNS},
   NPRGPEW=${NPRGPEW},
   NPRTRW=${NPRTRW},
   NPRTRV=${NPRTRV},
 /
 &NAMIO_SERV
   NPROC_IO=${IOSERVER_NPROC},
   NMSG_LEVEL_SERVER=1,
   NMSG_LEVEL_CLIENT=1,
   NPROCESS_LEVEL=5,
 /
 &NAMDIM
   NPROMA=${NPROMA},
 /
 &NAMPAR1
   LEQ_REGIONS=${LEQ_REGIONS},
   NSTRIN=${NSTRIN},
   NSTROUT=${NSTROUT},
   LSYNC_SLCOM=${LSYNC_SLCOM},
   LSYNC_POSTSLCOM2=${LSYNC_POSTSLCOM2},
 /
 &NAMCT0
   NOPT_MEMORY=${NOPT_MEMORY},
 /
 &NAMTRANS0
   NSTACK_MEMORY_TR=${NSTACK_MEMORY_TR},
 /
 &NAMRIP
    CSTOP='h${CONFIG_STOP}',
    TSTEP=${CONFIG_TSTEP},
 /
 &NAMFAINIT
   JPXLAT=${CONFIG_JPXLAT},
 /
" -i fort.4
