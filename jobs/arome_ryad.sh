#!/usr/bin/bash

# x86 hpc
# #SBATCH -p normal256
# #SBATCH --mem=247000
# #SBATCH -n 128
# #SBATCH -c 2
# #SBATCH -N 2
# #SBATCH --time=00:02:00
# #SBATCH --export=NONE
# #SBATCH --exclusiv

# VEC
# #PBS -q clim
# #PBS -v NN=1             # number of nodes
# #PBS -v NE=1             # number of VE/node
# #PBS -v CPE=8            # number of cpu/VE
# #PBS -v THREADS=2        # number of threads/VE
# #PBS -v X86CPU=2         # number of x86 cpu/node (maximum 24 - 0 means disabled)
# #PBS -b ${NN}            # no. of logical hosts
# #PBS -l elapstim_req=00:03:00
# #PBS --venum-lhost=${NE} # no. of Vector Engines per logical host
# #PBS --cpunum-lhost=1
# #PBS --use-hca=2                      # Number of HCA per logical host HCA=Host Channel Adapter , eg IB Cards 
# #PBS -v NMPI_DAEMON_PATH=/opt/nec/ve/mpi/2.22.0/libexec/mpid
# #PBS -v VE_LD_PRELOAD=libveaccio.so.1 #use accelerated I/O
# #PBS -T necmpi
# #PBS -l coresz_prc=0                  #no core dumps
# #PBS -j o

set -x

# Set the number of nodes, tasks per node and threads per task for the model :
NNODE_FC=1
NTASK_FC=3
NOPMP_FC=2
# Set the total number of MPI tasks for the model :
NPROC_FC=$((NNODE_FC*NTASK_FC))

# Set the number of nodes, tasks per node and threads per task for the I/O server :
NNODE_IO=1
NTASK_IO=1
# Set the total number of MPI tasks for the I/O server :
NPROC_IO=$((NNODE_IO*NTASK_IO))

# Set the model and choose its resolution :
MODEL=arome
GRID=el29
#GRID=el700
#GRID=ec650

# Running method (std: x86_64, vec: vector engine cards, gpu: gpu accelerator using openacc singlecolumn)
RUNMETHOD=std

# Pack containing the executable of the model :
THISPACK_MDL=... # To be setup by the user

# Pack containing the executable of the IO server :
if [ "$RUNMETHOD" == "vec" ] ; then
# If the vector host is used:
  THISPACK_IOS=... # To be setup by the user
  ON_VECTOR_HOST="-vh"
else
  THISPACK_IOS=$THISPACK_MDL
  unset ON_VECTOR_HOST
fi

# Model executable :
MASTER=$THISPACK_MDL/bin/MASTERODB
# I/O server executable :
IOSERVER=$THISPACK_IOS/bin/MASTERODB

# root directory of this benchmark :
RAPSMF2024=... # To be setup by the user
# root directory of input datasets of this benchmark :
DATADIR=... # To be setup by the user
# root directory of driving namelists of this benchmark :
NAMELISTS=$RAPSMF2024/cy49t0.namelists
# PATH to various tools provided and used in this benchmark :
export PATH=$RAPSMF2024/tools:$PATH

# Reference profile :
REFPROF=$RAPSMF2024/references/cy49t0.forecast_${MODEL}_$GRID/NODE.001_01

# root directory for the outputs (profile and NODE):
ROOT_OUTDIR=... # To be setup by the user
# final directory for the outputs (profile and NODE):
OUTDIR=$ROOT_OUTDIR/${MODEL}_${GRID}_${RUNMETHOD}_${RANDOM}
mkdir -p $OUTDIR

# Environment variables :

# DrHook internal profiler :
export DR_HOOK=1
export DR_HOOK_IGNORE_SIGNALS=-1
export DR_HOOK_SILENT=1
export DR_HOOK_SHOW_PROCESS_OPTIONS=0
export DR_HOOK_OPT=prof
# For timing, disable DrHook as follows :
# export DR_HOOK=0
# unset DR_HOOK_OPT

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

if [ "$RUNMETHOD" == "vec" ]; then
	# MPI
	export NMPI_IB_FAST_PATH=OFF # NEC suggested OFF
	export NMPI_IB_RNDV_PROTOCOL=GET
	export NMPI_IB_VH_MEMCPY_THRESHOLD=131072
	export NMPI_IB_VH_MEMCPY_SPLIT_THRESHOLD=131072
	# IO LFI
	export LFI_ARTICLE_LENGTH=3072 #standard: 512, max. 3072
	# VE settings
	export VE_FORT_UFMTENDIAN=all
	export VE_BLAS_DGEMM_MODE=GREEDYA #needed for reporducibility
	export VE_FORT_RECORDBUF=3072000 # make input buffer longer
	export VE_INIT_HEAP=ZERO
	export VE_FPE_ENABLE=(DIV,FOF,FUF,INV,INE)
	# verbose execution summary
	export VE_TRACEBACK=VERBOSE
fi

ulimit -c 0

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
tar xf couplers.tar

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

if [ "$GRID" = "el29" ] ; then
# Prefer default square MPI distribution at low resolution for testing
  NPRGPNS="-"
  NPRGPEW="-"
  NPRTRW="-"
  NPRTRV="-"
# Number of MPI tasks for traditional I/O decoding :
  NSTRIN=$NPROC_FC
elif [ "$RUNMETHOD" == "vec" ] ; then
# Prefer 1-way MPI distribution by default
  NPRGPNS=$NPROC_FC
  NPRGPEW=1
  NPRTRW=$NPROC_FC
  NPRTRV=1
# Number of MPI tasks for traditional I/O decoding :
# (a reduced value of NSTRIN seems to save memory without impacting the performance)
  NSTRIN=$((NPROC_FC/2))
else
# Prefer default square MPI distribution by default
  NPRGPNS="-"
  NPRGPEW="-"
  NPRTRW="-"
  NPRTRV="-"
# Number of MPI tasks for traditional I/O decoding :
  NSTRIN=$NPROC_FC
fi

# Directory of coupling files for the I/O server if it is used. Set it to "-" if you do not want the I/O server to read them
CIFDIR="${TMPDIR}/couplers"

if [ "$RUNMETHOD" == "vec" ] ; then
# Miscellaneous architecture-specific optimizations
  LOPT_SCALAR=.FALSE.
# (fftw looks less efficient than the traditional fft992)
  LFFTW=.FALSE.
  if [ "$GRID" = "el29" ] ; then
# Vector length (a small value makes more realistic testing at low resolution)
    NPROMA=-255
  else
    NPROMA=-1023
  fi
# Reading of FA does not work with openmp even with 1 thread (and perhaps not very useful)
  NREAD_FA_WITH_OPENMP=0
else
# Miscellaneous architecture-specific optimizations
  LOPT_SCALAR=.TRUE.
# (fftw is more efficient than the traditional fft992)
  LFFTW=.TRUE.
# Vector length or cache-blocking factor (a small value to keep data in memory cache)
  NPROMA=-16
# Reading of FA with openmp : not convincing but ...
  NREAD_FA_WITH_OPENMP=0
fi

# cache-blocking factor for microphysics (default value is NPROMA*NFLEVG) - not of much help for now
NPROMICRO="-"

# Number of MPI tasks for traditional I/O encoding :
NSTROUT=${NPROC_FC}

# Stack (1) vs heap (2) allocation in the model gridpoint computations :
NOPT_MEMORY=2

# Stack (1) vs heap (0) allocation in the grid-point MPI transpositions of the spectral transforms :
NSTACK_MEMORY_TR=1

# Set the variable below to .TRUE. to activate a MPI barrier before the semi-lagrangian communications :
LSYNC_SLCOM=.FALSE.

# Set the variable below to .TRUE. to activate a MPI barrier after the semi-lagrangian communications :
LSYNC_POSTSLCOM2="-"

# Set the next variable to 1 in order to read fields in random order (supposed to be faster)
NREAD_FA_RANDOMLY=0

# Reduce forecast range (expressed in hours) for debugging :
STOP=24

# Set NPRINTLEV=1 to increase the listing verbosity :
NPRINTLEV="-"

# Model time step and dimension parameter - do not change it !
if [ "$GRID" = "el29" ] ; then
  TSTEP=100.
  JPXLAT="-"
elif [ "$GRID" = "el700" ] ; then
  TSTEP=50.
  JPXLAT="-"
elif [ "$GRID" = "ec650" ] ; then
  TSTEP=36.
  JPXLAT=2700
else
  echo "Unknown resolution"
  exit 1
fi

# Namelists transformations :
xpnam --delta="
 &NAMTRANS
   LFFTW=${LFFTW},
 /
 &NAMPAR0
   NPRINTLEV=${NPRINTLEV},
   LOPT_SCALAR=${LOPT_SCALAR},
   NPROC=${NPROC_FC},
   NPRGPNS=${NPRGPNS},
   NPRGPEW=${NPRGPEW},
   NPRTRW=${NPRTRW},
   NPRTRV=${NPRTRV},
 /
 &NAMIO_SERV 
   NPROC_IO=${NPROC_IO}, 
   CIFDIR='${CIFDIR}',
 /
 &NAMDIM
   NPROMA=${NPROMA},
 /
 &NAM_PARAM_ICEN
   NPROMICRO=${NPROMICRO},
 /
 &NAMPAR1
   NSTRIN=${NSTRIN},
   NSTROUT=${NSTROUT},
   LSYNC_SLCOM=${LSYNC_SLCOM},
   LSYNC_POSTSLCOM2=${LSYNC_POSTSLCOM2},
   NDISTIO(12)=${NREAD_FA_WITH_OPENMP},
   NDISTIO(13)=${NREAD_FA_RANDOMLY},
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
ls -lrt couplers

# Usually needed for Open-MP support or large stack management :
ulimit -s unlimited

# Run :

time mpirun -np $NPROC_FC $MASTER : $ON_VECTOR_HOST -np $NPROC_IO $IOSERVER
# at Meteo-France
# time mpiauto -np $NPROC_FC -nnp $NTASK_FC $MASTER : -np $NPROC_IO -nnp $NTASK_IO $IOSERVER

# Print out the listing :
cat NODE.001_01
cp NODE.001_01  $OUTDIR/.

# Check the validity of scientific results :
diffNODE.001_01 NODE.001_01 $REFPROF > diffNODE.001_01.out
cp diffNODE.001_01.out $OUTDIR/.
cat diffNODE.001_01.out

# Print out the merged DrHook profiles, if any
if [ -f drhook.prof.1 ] ; then
  cat drhook.prof.* | drhook_merge_walltime_max > drhook.prof
  cp drhook.prof $OUTDIR/.
  cat drhook.prof
fi

ls -lrt

