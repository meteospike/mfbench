#!/bin/bash

# Some extra OpenMP settings
export OMP_STACKSIZE=4G
export KMP_STACKSIZE=4G
export KMP_MONITOR_STACKSIZE=4G
export OMP_NUM_THREADS=$MASTER_THREADS
