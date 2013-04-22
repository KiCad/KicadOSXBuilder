#Kicad OSX Builder

This is a build system to build universal OSX kicad binaries with scripting support.
It packs wxpython and pcbnew plugins together into the data folder at the root of the
output directory (which can be found in package/), and wraps all kicad apps to use
the libraries in there.

You have got to simply invoke the **build.sh** script to build a universal 32 and 64bit
product in release configuration.

It's my first experiencie packaging Mac OSX apps, so it can be done better for sure,
it works anyway ;)

##Options

The **build.sh** script can handle the following command line arguments:

-a / --arch `<architecture_string>`: specify an architecture to build. You can specify
multiple instaces of this argument to specify multiple architectures. If this argument
is not specified the script will build a universal i386 and x86_64 application.

-c / --cpus `<cpu_count>`: specify the number of CPUs (or cores) in your system. The
build script will spawn twice at much build threads so that your system is optimally
used.

-d / --debug: build a debug configuration binary.

-h / --help: show help text.