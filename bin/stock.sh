# old options from flexpart

while [[ $# -gt 0 ]]; do

  mfb=${1,,}
  shift

  if [ "$mfb" == "help" ]; then

    echo "No need."

  elif [ "$mfb" == "replay" ]; then

    \cd $MFBENCH_ROOT/jobs
    source $MFBENCH_ROOT/options/OPER/$MFBENCH_OPCONF
    if [ -f replay-mfbench.$MFBENCH_XPID.out ]; then
      \mv replay-mfbench.$MFBENCH_XPID.out replay-mfbench.$MFBENCH_XPID.prev
    fi
    ./replay-mfbench.sh | tee replay-mfbench.$MFBENCH_XPID.out

  elif [ "$mfb" == "naml" ]; then

    echo "$MFBENCH_ROOT/options/NAMELISTS:"
    \cd $MFBENCH_ROOT/options/NAMELISTS
    if [ "$1" == "" ]; then
      ichoice=0
    else
      ichoice=$1
      shift
    fi
    inum=0
    actualdef=$(\ls -l | fgrep 'DEFAULT ->' | awk '{print $NF}')
    for naml in $(\ls -1 *.naml); do
      if [ -f "$naml" -a "$naml" != "DEFAULT" ]; then
        inum=$((inum+1))
        if [[ $ichoice -eq 0 ]]; then
          cstar=" "
          if [ "$naml" == "$actualdef" ]; then
            cstar="*"
          fi
          spinfo="sp:"
          for spnum in $(fgrep ispec_index $naml | awk '{if ($2+0>0) print $2+0}' FS="[=,]"); do
            spfmt=$(printf "%03d" $spnum)
            spname=$(fgrep cname  $MFBENCH_ROOT/options/SPECIES/NAMELIST_SPECIES_$spfmt | cut -f2 -d "'")
            spinfo="$spinfo $spname,"
          done
          printf "[%2d]%s %-40s  %s\n" $inum "$cstar" "$naml" "$(echo $spinfo | sed 's/.$//')"
        elif [[ $inum -eq $ichoice ]]; then
          echo "Select DEFAULT as <$naml>"
          \rm -f DEFAULT
          \ln -s $naml DEFAULT
        fi
      fi
    done

  elif [ "$mfb" == "namless" ]; then

    less $MFBENCH_ROOT/options/NAMELISTS/DEFAULT

  elif [ "$mfb" == "namedit" ]; then

    \vi $MFBENCH_ROOT/options/NAMELISTS/DEFAULT

  elif [ "$mfb" == "make" ]; then

    \cd $MFBENCH_ROOT/src
    if [ "$1" == "" ]; then
      make
      if [ "$?" == "0" ]; then
        set -- "bkup"
      fi
    else
      make $*
      shift $#
    fi

  elif [ "$mfb" == "bkup" ]; then

    MFBENCH_STAMP=$(date '+%Y%m%d%H%M%S')
    \cd $MFBENCH_ROOT/src
    MFBENCH_LASTBKUP="$MFBENCH_TMPDIR/mfbench-bkup-$MFBENCH_STAMP"
    \mkdir -p $MFBENCH_LASTBKUP
    if [ -d "$MFBENCH_LASTBKUP" ]; then
      \cp Makefile *.f90 $MFBENCH_LASTBKUP/
      echo "bkup: $MFBENCH_LASTBKUP"
    else
      echo "Could not create bkup dir: $MFBENCH_LASTBKUP" >&2
    fi

  elif [ "$mfb" == "bklist" ]; then

    \ls -lrtd $MFBENCH_TMPDIR/mfbench-bkup-*

  elif [ "$mfb" == "bkdiff" ]; then

    \cd $MFBENCH_ROOT/src
    MFBENCH_LASTBKUP=$(\ls -1rtd $MFBENCH_TMPDIR/mfbench-bkup-* | tail -1)
    echo $MFBENCH_LASTBKUP
    if [ -d "$MFBENCH_LASTBKUP" ]; then
      if [ "$*" == "" ]; then
        for file in *.f90; do
          diff -q -b $MFBENCH_LASTBKUP/$file $file
        done
      else
        for file in $*; do
          echo "diff $MFBENCH_LASTBKUP/$file $file"
          diff $MFBENCH_LASTBKUP/$file $file
          shift
        done
      fi
    else
      echo "Could not find last bkup" >&2
    fi

  elif [ "$mfb" == "bkget" ]; then

    \cd $MFBENCH_ROOT/src
    MFBENCH_LASTBKUP=$(\ls -1rtd $MFBENCH_TMPDIR/mfbench-bkup-* | tail -1)
    if [ -d "$MFBENCH_LASTBKUP" ]; then
      for file in $*; do
        echo "cp $MFBENCH_LASTBKUP/$file $file"
        \mv $file $file.new
        \cp $MFBENCH_LASTBKUP/$file $file
        shift
      done
    else
      echo "Could not find last bkup" >&2
    fi

  elif [ "$mfb" == "run" ]; then

    \cd $MFBENCH_ROOT/jobs
    if [ -f submit-mfbench.$MFBENCH_XPID.out ]; then
      \mv submit-mfbench.$MFBENCH_XPID.out submit-mfbench.$MFBENCH_XPID.prev
    fi
    ./submit-mfbench.sh | tee submit-mfbench.$MFBENCH_XPID.out

  elif [ "$mfb" == "debug" -o "$mfb" == "dbug" ]; then

    export MFBENCH_DEBUG="gdb"

    set -- "run"

  elif [ "$mfb" == "tests" ]; then

    \cd $MFBENCH_TMPDIR
    if [ "$1" == "" ]; then
      TESTLIST="$MFBENCH_TESTS"
    else
      TESTLIST="$*"
      shift $#
    fi
    for test in $TESTLIST; do
      if [ -f "$MFBENCH_ROOT/src/test_$test" ]; then
        echo "MFBENCH TEST RUNNING: $test"
        $MFBENCH_ROOT/src/test_$test
        echo "----------"
      else
        echo "MFBENCH TEST UNKNOWN: $test" >&2
      fi
    done

  elif [ "$mfb" == "redo" ]; then

    cd $MFBENCH_ROOT/src
    make
    \cd $MFBENCH_ROOT/jobs
    if [ -f submit-mfbench.$MFBENCH_XPID.out ]; then
      \mv submit-mfbench.$MFBENCH_XPID.out submit-mfbench.$MFBENCH_XPID.prev
    fi
    ./submit-mfbench.sh | tee submit-mfbench.$MFBENCH_XPID.out

  elif [ "$mfb" == "job" ]; then

    \cd $MFBENCH_ROOT/jobs
    sbatch submit-mfbench.sh

  elif [ "$mfb" == "log" -o "$mfb" == "error" -o "$mfb" == "warning" -o "$mfb" == "inspect" ]; then

    \cd $MFBENCH_ROOT/jobs
    LASTLOG=$(\ls -1rt submit-mfbench.*.out | tail -1)
    if [ -f "$LASTLOG" ]; then
      if [ "$mfb" == "log" ]; then
        if [ "$1" == "" ]; then
          less $LASTLOG
        else
          echo "$LASTLOG"
          echo "---"
          fgrep -i "$*" $LASTLOG
          shift $#
        fi
      else
        fgrep -i "[$mfb]" $LASTLOG
      fi
    fi

  elif [ "$mfb" == "logdiff" ]; then

    \cd $MFBENCH_ROOT/jobs
    LASTLOG=$(\ls -1rt submit-mfbench.*.out | tail -1)
    REFLOG="$(basename $LASTLOG .out).ok"
    if [ -f "$REFLOG" ]; then
      echo "meld $REFLOG $LASTLOG"
      perl -pwe 's/\[\d\d:\d\d:\d\d\.\d+\]//go;' $REFLOG > $REFLOG.tmp
      perl -pwe 's/\[\d\d:\d\d:\d\d\.\d+\]//go;' $LASTLOG > $LASTLOG.tmp
      meld $REFLOG.tmp $LASTLOG.tmp
      \rm -f $REFLOG.tmp $LASTLOG.tmp
    else
      echo "Could not find reference file $REFLOG"
    fi

  elif [ "$mfb" == "llout" ]; then

    \ls -lrtd $MFBENCH_WORKDIR/submit*

  elif [ "$mfb" == "namout" -o "$mfb" == "namlout" ]; then

    if [ "$1" != "" -a "$1" == "$(($1+0))" ]; then
      nbout=$1
      shift
    else
      nbout=9999
    fi
    for dirout in $(\ls -1d $MFBENCH_WORKDIR/submit* | tail -$nbout); do
      if [ -f "$dirout/fort.4" -a -d "$dirout/outputs" ]; then
        nbcsv=$(ls -1 $dirout/outputs/part00_dump_*.csv 2>/dev/null | wc -l | tr -d ' ')
        if [ $nbcsv -gt 0 ]; then
          echo "-- $dirout [csv:$nbcsv]:"
          egrep -e 'idate_begin' -e 'itime_begin' -e 'idate_end' -e 'itime_end' \
                -e 'cpath_domains\([0-9]+,2\)' -e 'relp\([0-9]+\)%cname' \
                $dirout/fort.4 | cut -f1 -d "!"
        fi
      fi
    done

  elif [ "$mfb" == "clrout" ]; then

    for dirout in $(\ls -1d $MFBENCH_WORKDIR/submit*); do
      LASTOUT=$(\ls -1 $dirout/XP_COMPLETE $dirout/outputs/*_END 2>/dev/null | tail -1)
      if [ -d $dirout -a "$LASTOUT" == "" ]; then
        echo "cleaning $dirout"
        \rm -rf $dirout
      fi
    done

  elif [ "$mfb" == "cmp" ]; then

    LASTDIR=$(\ls -1rtd $MFBENCH_WORKDIR/submit*/outputs | tail -1)
    PREVDIR=$(\ls -1rtd $MFBENCH_WORKDIR/submit*/outputs | tail -2 | head -1)
    echo "Last rundir: $LASTDIR"
    echo "Prev rundir: $PREVDIR"
    \cd $LASTDIR
    for filedump in $(\ls -1 part00_dump_*[0-9] grid[0-9][0-9]_*[0-9] *.nc); do
      if [ -f "$PREVDIR/$filedump" ]; then
        cmp --quiet $filedump $PREVDIR/$filedump
        if [ "$?" == "0" ]; then
          echo "$filedump: ok"
        else
          echo "$filedump: <<differ>>"
        fi
      else
        echo "$filedump: not found"
      fi
    done

  elif [ "$mfb" == "out" ]; then

    if [ "$1" == "" ]; then
      num=1
    else
      num=$(($1+1))
      shift
    fi
    THISDIR=$(\ls -1rtd $MFBENCH_WORKDIR/submit*/outputs | tail -$num | head -1)
    \cd $THISDIR
    \pwd

  elif [ "$mfb" == "diff" ]; then

    LASTDIR=$(\ls -1rtd $MFBENCH_WORKDIR/submit*/outputs | tail -1)
    PREVDIR=$(\ls -1rtd $MFBENCH_WORKDIR/submit*/outputs | tail -2 | head -1)
    \cd $LASTDIR
    for filedump in $(\ls -1r part00_dump_*.csv); do
      if [ -f "$PREVDIR/$filedump" ]; then
        echo "Last csv: $LASTDIR/$filedump"
        echo "Prev csv: $PREVDIR/$filedump"
        echo "---"
        diff $PREVDIR/$filedump $filedump | fgrep '<' | head -10
        echo "---"
        diff $PREVDIR/$filedump $filedump | fgrep '>' | head -10
      fi
    done

  elif [ "$mfb" == "rmlast" ]; then

    LASTDIR=$(\ls -1rtd $MFBENCH_WORKDIR/submit* | tail -1)
    echo "remove rundir: $LASTDIR"
    if [ -d "$LASTDIR" ]; then
      \rm -rf $LASTDIR
    fi

  elif [ "$mfb" == "roll" ]; then

    numdir=0
    if [ "$1" == "" ]; then
      DIFFCONT="no"
    else
      DIFFCONT="$1"
      shift
    fi
    echo "Rolling cmp on mfbench outputs (continue is $DIFFCONT)"
    for LASTDIR in $(\ls -1td $MFBENCH_WORKDIR/submit*/outputs); do
      echo "---"
      numdir=$((numdir+1))
      numpun=$((numdir+1))
      PREVDIR=$(\ls -1td $MFBENCH_WORKDIR/submit*/outputs | head -$numpun | tail -1)
      echo "Last rundir: $LASTDIR"
      echo "Prev rundir: $PREVDIR"
      \cd $LASTDIR
      morediff=$DIFFCONT
      for filedump in $(\ls -1 part00_dump_*[0-9] grid[0-9][0-9]_*[0-9]); do
        if [ -f "$PREVDIR/$filedump" ]; then
          cmp --quiet $filedump $PREVDIR/$filedump
          if [ "$?" == "0" ]; then
            echo "$filedump: ok"
          else
            morediff="yes"
            echo "$filedump: <<differ>>"
          fi
        else
          morediff="yes"
          echo "$filedump: not found"
        fi
      done
      if [ "$morediff" == "no" ]; then
        break
      fi
    done
