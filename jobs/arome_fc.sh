#!/bin/bash
#SBATCH --job-name=aro
#SBATCH --partition=normal256
#SBATCH --export=NONE
#SBATCH --time=00:05:00
#SBATCH --mem=247000
#SBATCH --exclusiv
#SBATCH --verbose
#SBATCH --no-requeue
#SBATCH --nodes=1
## #SBATCH --ntasks-per-node=32
## #SBATCH --cpus-per-task=2

# Select your profile
mfb switch default

# Load and display current mfb profile variables
. mfb env

set -aex

# -----------------------------------------------------------------------------
# Ultimate overwriting of the profile
MFBENCH_FOO=2

# -----------------------------------------------------------------------------
# Actual configuration (most important features)
CONFIG_NAME=arome_fc
CONFIG_GRID=${MFBENCH_GRID:-el029}
CONFIG_CYCLE=$(mfb cycle)
CONFIG_XPSET=$CONFIG_CYCLE.$CONFIG_NAME.$CONFIG_GRID
CONFIG_FLOAT=$(mfb float)
CONFIG_PACK=${MFBENCH_PACK:-${CONFIG_CYCLE//cy/}_rapsmain.01.$MFBENCH_ARCH.$MFBENCH_OPTS}
CONFIG_DATA=$MFBENCH_INPUTS/$CONFIG_XPSET
CONFIG_OUTS=$MFBENCH_OUTPUTS/$CONFIG_XPSET
CONFIG_REFS=$MFBENCH_REFERENCES/$CONFIG_XPSET
CONFIG_CONST=$MFBENCH_INPUTS/$CONFIG_CYCLE.constants.expanded
CONFIG_STOP=24
CONFIG_TSTEP=auto
CONFIG_JPXLAT="-"
CONFIG_DRHOOK=on
CONFIG_VECTOR=off
CONFIG_METHODS=$(mfb methods)
CONFIG_STAMP=$(mfb stamp)
CONFIG_PROCINFO=off
CONFIG_CATNODE=${MFBENCH_CATNODE:-no}
CONFIG_RUNDIR=$(mfb rundir)

# -----------------------------------------------------------------------------
# Model executable / number of nodes, tasks per node, threads per task
MASTER_BIN=$MFBENCH_PACKS/$CONFIG_PACK/bin/MASTERODB
MASTER_NODES=1
MASTER_TASKS=32
MASTER_THREADS=2
MASTER_NPROC=$((MASTER_NODES*MASTER_TASKS))

# -----------------------------------------------------------------------------
# I/O server executable / number of nodes, tasks per node
IOSERVER_BIN=$MASTER_BIN
IOSERVER_NODES=1
IOSERVER_TASKS=1
IOSERVER_THREADS=4
IOSERVER_NPROC=$((IOSERVER_NODES*IOSERVER_TASKS))

set +ax

# -----------------------------------------------------------------------------
# Move to current running directory
\mkdir -p $CONFIG_RUNDIR
\cd $CONFIG_RUNDIR

# -----------------------------------------------------------------------------
# Check some top level elements
if [ ! -d $CONFIG_DATA ]; then
  echo "Initialisation data directory does not exists" >&2
  exit 1
fi
if [ ! -d $CONFIG_CONST ]; then
  echo "Constants data directory does not exists" >&2
  exit 1
fi
if [ ! -f $MASTER_BIN ]; then
  echo "Master binary does not exists" >&2
  exit 1
fi
if [ ! -f $IOSERVER_BIN ]; then
  echo "IO Server binary does not exists" >&2
  exit 1
fi

# -----------------------------------------------------------------------------
# Include env settings
set -x
source $MFBENCH_JOBS/include/env.drhook.$CONFIG_DRHOOK.sh
source $MFBENCH_JOBS/include/env.meminfo.sh
source $MFBENCH_JOBS/include/env.openmp.sh
source $MFBENCH_JOBS/include/env.mkl.sh
source $MFBENCH_JOBS/include/stack.clean.sh
source $MFBENCH_JOBS/include/stack.$CONFIG_FLOAT.sh
source $MFBENCH_JOBS/include/sys.misc.sh

# Fix time step for this configuration
if [ "$CONFIG_TSTEP" == "auto" ]; then
  source $MFBENCH_JOBS/include/step.$CONFIG_NAME.$CONFIG_GRID.sh
  echo "Set default time step to $CONFIG_TSTEP"
fi

# -----------------------------------------------------------------------------
# Copy background namelists
\cp $MFBENCH_NAMELISTS/$CONFIG_CYCLE.$CONFIG_NAME.nam fort.4
\cp $MFBENCH_NAMELISTS/$CONFIG_CYCLE.$CONFIG_NAME.sfx EXSEG1.nam

# Setup parallel geometry and top level optimisations (see documentation)
$MFBENCH_JOBS/include/namset.$CONFIG_NAME.sh

# Fix namelist according to processing unit (if needed)
$MFBENCH_JOBS/include/fixnam.$MFBENCH_PCUNIT.sh

# -----------------------------------------------------------------------------
# Import compilers wrapper (including mpirun)
set +x
source $MFBENCH_SCRIPTS_WRAPPERS/export_compilers.sh
set -x

# -----------------------------------------------------------------------------
# Execution loop on parallel methods

for this_method in $CONFIG_METHODS; do

  \mkdir -p $CONFIG_RUNDIR/$this_method
  \cd $CONFIG_RUNDIR/$this_method

  # Setting env variables related to this local path
  export ECCODES_SAMPLES_PATH=$PWD/eccodes/ifs_samples/grib1_mlgrib2
  export ECCODES_DEFINITION_PATH=$PWD/eccodes/definitions
  export RTTOV_COEFDIR=$PWD

  # Copy or link resolution-dependent data and constants
  for item in $CONFIG_DATA/* $CONFIG_CONST/*; do
    \ln -s $item .
  done

  # Copy updated namelists
  \cp ../fort.4 .
  \cp ../EXSEG1.nam .
  cat fort.4

  # Ultimate setup fix according to running method
  \rm -f lparallelmethod.txt
  \rm -f lsynchost.txt
  source $MFBENCH_JOBS/include/setup.$this_method.sh

  # Output directory
  this_out=$CONFIG_OUTS/$CONFIG_STAMP.$this_method
  \mkdir -p $this_out

  # Log actual environement
  env | fgrep -e CONFIG_ -e MFBENCH_ -e MASTER_ -e IOSERVER_ | sort -u > $this_out/experiment.env

  # Run
  \ls -lrt
  $MFBENCH_COMPILER_MPIRUN \
       --nn $MASTER_NODES   --nnp $MASTER_TASKS   --openmp $MASTER_THREADS  -- $MASTER_BIN \
    -- --nn $IOSERVER_NODES --nnp $IOSERVER_TASKS --openmp $IOSERVER_THREADS -- $IOSERVER_BIN

  # Save node output
  if [ -f NODE.001_01 ]; then
    \cp NODE.001_01 $this_out/$CONFIG_NAME.$this_method.node.001
    [[ "$CONFIG_CATNODE" == "yes" ]] &&  cat NODE.001_01
  fi

  # Check the validity of scientific results
  this_ref=$CONFIG_REFS
  if [ -d $this_ref ]; then
    echo "$this_ref/NODE.001_01" > $this_out/$CONFIG_NAME.$this_method.ref
    $MFBENCH_SCRIPTS/tools/diffNODE $this_ref/NODE.001_01 NODE.001_01 | tee $this_out/$CONFIG_NAME.$this_method.diff
  else
    echo "Warning: could not find any reference for this configuration" >&2
  fi

  # Print out the merged DrHook profiles, if any
  if [ -f drhook.prof.1 ] ; then
    \cp drhook.prof.* $this_out/
    cat drhook.prof.* | $MFBENCH_SCRIPTS/tools/drhook_merge_walltime_max | tee $this_out/$CONFIG_NAME.$this_method.max
  fi

  \ls -lrt

done

# Intra comparaisons
\cd $CONFIG_RUNDIR

for this_cmp in $(< $MFBENCH_CONF/mfbench-methods-cmp); do
  diff1=$(echo $this_cmp | cut -d ":" -f1)
  diff2=$(echo $this_cmp | cut -d ":" -f2)
  if [[ -f "$diff1/NODE.001_01" && -f "$diff2/NODE.001_01" ]]; then
    echo "DIFF NODE $diff1 / $diff2"
    $MFBENCH_SCRIPTS/tools/diffNODE $diff1/NODE.001_01 $diff2/NODE.001_01
  else
    echo "Could not find $diff1 output or $diff2 output" >&2
  fi
done
