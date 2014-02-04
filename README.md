#Kicad OSX Builder

This is a build system to build universal OSX kicad binaries with scripting support.
It packs wxpython and pcbnew plugins together into the data folder at the root of the
output directory (which can be found in package/), and wraps all kicad apps to use
the libraries in there.

You have got to simply* invoke the **build.sh** script to build a universal 32 and 64bit
product in release configuration.

It's my first experience packaging Mac OSX apps, so it can be done better for sure,
it works anyway ;)

*Note: Before running this script, some prerequisites need to be satisfied.

1. bzr, bzrtools, glew and swig must be installed. They can be easily installed by first installing MacPorts (http://www.macports.org/install.php) and running "sudo port install bzr bzrtools glew swig".
2. An account is required on LaunchPad.net. Create an account, and upload a generated SSH key to the website. (https://help.launchpad.net/YourAccount/CreatingAnSSHKeyPair)
3. In terminal, run 'bzr launchpad-login username' and 'bzr whoami "Your Name name@example.com"' using the login information from launchpad.net.


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

-s / --steps: Select which steps to execute, either a single step number in the range
[1-8] or a comma separated list of steps or a step number followed by a comma followed 
by ... ( eg. 3,... ). The later syntax executes the step provided plus the following 
steps up until the last.

-C / --cern-branch : Selects the CERN branch, that includes push&shove router, GAL 
and new TOOL framework

