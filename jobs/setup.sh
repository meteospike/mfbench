#!/bin/bash

# Perform all the mfb settings in a raw up !
mfb init
mfb set flavour std
mfb set arch OMGNU1140
mfb set opts 2s
mfb env

# Install
mfb select-bundle
mfb install yaml
mfb tools libraries dummy

# Create main gmk pack whith full hub and meteo librairies
mfb select-gmkfile
mfb set autopack yes
mfb mkmain

# Compile and load !
mfb compile
