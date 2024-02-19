#!/bin/bash

set -x

# Set the number of nodes, tasks per node and threads per task for the model :
NNODE_FC=1
NTASK_FC=3
NOPMP_FC=2
# Set the total number of MPI tasks for the model :
NPROC=$((NNODE_FC*NTASK_FC))

# Set the number of nodes, tasks per node and threads per task for the I/O server :
NNODE_IO=1
NTASK_IO=1
# Set the total number of MPI tasks for the I/O server :
NPROC_IO=$((NNODE_IO*NTASK_IO))

# Set the model and choose its resolution :
MODEL=arpege
GRID=tl48
#GRID=tl798
#GRID=tl1798
#GRID=tc1799

# Model executable :
MASTER=/home/khatib/pack/49t0_fullrapslike.07%gelato/bin/MASTERODB
# I/O server executable :
IOSERVER=/home/khatib/pack/49t0_fullrapslike.07%gelato/bin/MASTERODB

# root directory of this benchmark :
RAPSMF2024=/home/khatib/Calcul2025
# root directory of input datasets of this benchmark :
DATADIR=$RAPSMF2024/data_lfm
# root directory of driving namelists of this benchmark :
NAMELISTS=$RAPSMF2024/cy49t0.namelists
# PATH to various tools provided and used in this benchmark :
export PATH=$RAPSMF2024/tools:$PATH


# Environment variables :

# DrHook internal profiler :
export DR_HOOK=0
export DR_HOOK_IGNORE_SIGNALS=-1
export DR_HOOK_SILENT=1
export DR_HOOK_SHOW_PROCESS_OPTIONS=0
#export DR_HOOK_OPT=prof

# Arpege/Arome-specific :
export MPL_MBX_SIZE=2048000000
export EC_PROFILE_HEAP=0
export EC_PROFILE_MEM=0
export EC_MPI_ATEXIT=0
export EC_MEMINFO=0

# Others :
export OMP_STACKSIZE=4G
export KMP_STACKSIZE=4G
export KMP_MONITOR_STACKSIZE=4G
export OMP_NUM_THREADS=$NOPMP_FC

# Change to a temporary directory :
OPWD=$PWD
if [ ! "$TMPDIR" ] ; then
  TMPDIR=$(mktemp -u)
fi
mkdir -p $TMPDIR
cd $TMPDIR

# Small output files can be produced on a directory on NFS :
TMPNFS=${TMPNFS:=$TMPDIR}
mkdir -p $TMPNFS

# Copy or link resolution-dependent data to $TMPDIR :
DATASET=$DATADIR/cy49t0.forecast_${MODEL}_$GRID
for file in $DATASET/* ; do
  ln -s $file .
done

# Untar archives to get local filenames :
tar xf links.tar

# Untar constants datafiles :
for file in $DATADIR/cy49t0.constants/*.tar.gz; do
  tar xfz $file
done

# Set constants environments :
export ECCODES_SAMPLES_PATH=$PWD/eccodes/ifs_samples/grib1_mlgrib2
export ECCODES_DEFINITION_PATH=$PWD/eccodes/definitions
export RTTOV_COEFDIR=$PWD

# Copy the background namelists files to $TMPDIR :
/bin/cp $NAMELISTS/${MODEL}/namelistfcp fort.4
/bin/cp $NAMELISTS/${MODEL}/namel_previ_surfex EXSEG1.nam

# Adapt the background namelist to this specific source code release :
/bin/cp $NAMELISTS/${MODEL}/gnam .
xpnam -i --dfile=gnam fort.4

# Adapt namelists parameters to the chosen resolution or the preferred architecture profile :
# set VECTOR_ENGINE=1 for vector engines :
VECTOR_ENGINE=0

if [ "$GRID" = "tl48" ] ; then
# Prefer default square MPI distribution at low resolution for testing
  NPRGPNS="-"
  NPRGPEW="-"
  NPRTRW="-"
  NPRTRV="-"
# Number of MPI tasks for traditional I/O decoding :
  NSTRIN=$NPROC
# (Fast Legendre Transforms do not work at very low resolution)
  LUSEFLT=.FALSE.
elif [ $VECTOR_ENGINE -eq 1 ] ; then
# Prefer 1-way MPI distribution by default
  NPRGPNS=$NPROC
  NPRGPEW=1
  NPRTRW=$NPROC
  NPRTRV=1
# Number of MPI tasks for traditional I/O decoding :
# (a reduced value of NSTRIN seems to save memory without impacting the performance)
  NSTRIN=$((NPROC/2))
# (Traditional Legendre Transforms are faster on vector engines)
  LUSEFLT=.FALSE.
else
# Prefer default square MPI distribution by default
  NPRGPNS="-"
  NPRGPEW="-"
  NPRTRW="-"
  NPRTRV="-"
# Number of MPI tasks for traditional I/O decoding :
  NSTRIN=$NPROC
# (Fast Legendre Transforms are faster on cache-based machines)
  LUSEFLT=.TRUE.
fi

if [ $VECTOR_ENGINE -eq 1 ] ; then
# Miscellaneous architecture-specific optimizations
  LOPT_SCALAR=.FALSE.
  LEQ_REGIONS=.FALSE.
# (fftw looks less efficient than the traditional fft992)
  LFFTW=.FALSE.
  if [ "$GRID" = "tl48" ] ; then
# Vector length (a small value makes more realistic testing at low resolution)
    NPROMA=-255
  else
    NPROMA=-1023
  fi
else
# Miscellaneous architecture-specific optimizations
  LOPT_SCALAR=.TRUE.
  LEQ_REGIONS=.TRUE.
# (fftw is more efficient than the traditional fft992)
  LFFTW=.TRUE.
# Vector length or cache-blocking factor (a small value to keep data in memory cache)
  NPROMA=-50
fi

# Number of MPI tasks for traditional I/O encoding :
NSTROUT=${NPROC}

# Stack (1) vs heap (2) allocation in the model gridpoint computations :
NOPT_MEMORY=2

# Stack (1) vs heap (0) allocation in the grid-point MPI transpositions of the spectral transforms :
NSTACK_MEMORY_TR=1

# Set the variable below to .TRUE. to activate a MPI barrier before the semi-lagrangian communications :
LSYNC_SLCOM=.FALSE.

# Set the variable below to .TRUE. to activate a MPI barrier after the semi-lagrangian communications :
LSYNC_POSTSLCOM2=.FALSE.

# Reduce forecast range (expressed in hours) for debugging :
STOP=24

# Set NPRINTLEV=1 to increase the listing verbosity :
NPRINTLEV="-"

# Model time step and dimension parameter - do not change it !
if [ "$GRID" = "tl48" ] ; then
  TSTEP=1800.
  JPXLAT="-"
elif [ "$GRID" = "tl798" ] ; then
  TSTEP=600.
  JPXLAT="-"
elif [ "$GRID" = "tl1798" ] ; then
  TSTEP=240.
  JPXLAT="-"
elif [ "$GRID" = "tc1799" ] ; then
  TSTEP=120.
  JPXLAT=3600
else
  echo "Unknown resolution"
  exit 1
fi

# Namelists transformations :
xpnam --delta="
 &NAMTRANS
   LUSEFLT=${LUSEFLT},
   LFFTW=${LFFTW},
 /
 &NAMPAR0
   NPRINTLEV=${NPRINTLEV},
   LOPT_SCALAR=${LOPT_SCALAR},
   NPROC=${NPROC},
   NPRGPNS=${NPRGPNS},
   NPRGPEW=${NPRGPEW},
   NPRTRW=${NPRTRW},
   NPRTRV=${NPRTRV},
 /
 &NAMIO_SERV 
   NPROC_IO=${NPROC_IO}, 
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
    CSTOP='h${STOP}',
    TSTEP=${TSTEP},
 /
 &NAMOPH
   CFNHWF='${TMPNFS}/ECHIS',
 /
 &NAMDDH
   CFPATHDDH='${TMPNFS}/',
 /
 &NAMFAINIT
   JPXLAT=${JPXLAT},
 /
" -i fort.4

# print the final namelists :
cat fort.4

ls -lrt

# Usually needed for Open-MP support or large stack management :
ulimit -s unlimited

# Run :

time mpirun -np $NPROC $MASTER : -np $NPROC_IO $IOSERVER

# Print out the listing :
cat NODE.001_01

# Check the validity of scientific results :
diffNODE.001_01 NODE.001_01 $RAPSMF2024/references/cy49t0.forecast_${MODEL}_$GRID/arpege.sh_atos.out

# Print out the merged DrHook profiles, if any
if [ -f drhook.prof.1 ] ; then
  cat drhook.prof.* | drhook_merge_walltime_max
fi

ls -lrt

cd $OPWD
/bin/rm -rf $TMPDIR

