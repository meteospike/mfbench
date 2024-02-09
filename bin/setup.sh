#!/bin/bash

# Perform all the mfb settings in a raw up !
mfb init
mfb set pcunit std
mfb set arch OMGNU1140
mfb set opts 2s
mfb env

# Install
mfb bundle-auto
mfb install yaml
mfb install tools
mfb install libraries dummies

# Create main gmk pack whith full hub and meteo librairies
mfb gmkfile-auto
mfb set autopack yes
mfb mkmain

# Compile and load !
mfb compile
