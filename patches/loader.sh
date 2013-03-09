#!/bin/sh

# this is script wraps the original binary application, 
# and sets the library paths just before launching

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

export DYLD_LIBRARY_PATH=$DIR/../../../kicad.app/Contents/Frameworks:$DYLD_LIBRARY_PATH
export PYTHONPATH=$DIR/../../../kicad.app/Contents/Frameworks/python2.7/site-packages/:$PYTHONPATH

echo $PYTHONPATH

$DIR/`basename $0`.bin $*
