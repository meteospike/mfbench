#!/bin/bash

# This option is not yet available in gpu source pack

echo "Remove LSYNC_POSTSLCOM2 key from namelist in '$MFBENCH_PCUNIT' case"

$MFBENCH_SCRIPTS/tools/xpnam --delta="
 &NAMPAR1
   LSYNC_POSTSLCOM2=-
 /
" -i fort.4

