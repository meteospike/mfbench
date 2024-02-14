#!/bin/bash

cat /proc/cpuinfo

if [ -f /usr/bin/nvidia-smi ]; then
  set +e
  /usr/bin/nvidia-smi
  set -e
fi
