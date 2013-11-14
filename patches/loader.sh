#!/bin/sh

# this is script wraps the original binary application, 
# and sets the library paths just before launching

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

export KICAD_APP=$DIR/../../../kicad.app
export KICAD_DATA=$DIR/../../../data
export KICAD_PATH=$KICAD_DATA

# let the apps find the libraries at startup
export DYLD_LIBRARY_PATH=$KICAD_APP/Contents/Frameworks:$DYLD_LIBRARY_PATH

# let python scripting find our modules
export PYTHONPATH=$KICAD_APP/Contents/Frameworks/python2.7/site-packages/:$PYTHONPATH

export KICAD=$KICAD_DATA

$DIR/`basename $0`.bin "$*"
