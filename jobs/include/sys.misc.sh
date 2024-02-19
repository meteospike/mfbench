#!/bin/bash

[[ "$CONFIG_PROCINFO" == "yes" ]] && cat /proc/cpuinfo

if [ "$MFBENCH_PCUNIT" == "gpu" ]; then
  if [ -f /usr/bin/nvidia-smi ]; then
    set +e
    /usr/bin/nvidia-smi
    set -e
  fi
fi
