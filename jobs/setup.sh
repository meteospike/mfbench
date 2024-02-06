#!/bin/bash

# Perform all the mfb settings in a raw up !
mfb env
exit 0

# Install
mfb select-bundle
mfb install yaml tools libraries dummy

# Create main gmk pack whith full hub and meteo librairies
mfb select-gmkfile
mfb set autopack yes
mfb mkmain

# Compile and load !
mfb compile
