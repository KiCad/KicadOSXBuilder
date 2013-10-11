SCRIPT_DIRECTORY="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

BUILD_TYPE=Release            # Set to the users desired build type
BUILD_ARCHITECTURES=()        # The architectures to build for
BUILD_STEPS=()                # Which steps to build
MAKE_THREAD_COUNT=0           # The number of threads for make to use
CPU_COUNT=4                   # The number of CPUs (core) in the system (defaults to 4)

KICAD_DIRECTORY=kicad
KICAD_BRANCH="lp:~cern-kicad/kicad/testing"
# KICAD_BRANCH="lp:kicad"
# KICAD_BRANCH="lp:~kicad-testing-committers/kicad/testing"
LIBRARY_DIRECTORY=library

WXPYTHON_VERSION_MAJOR=2.9
#WXPYTHON_VERSION_MINOR=5
WXPYTHON_VERSION_MINOR=4
WXPYTHON_VERSION="${WXPYTHON_VERSION_MAJOR}.${WXPYTHON_VERSION_MINOR}.0"
WXPYTHON_SOURCE_DIRECTORY=wxPython-src-$WXPYTHON_VERSION
WXPYTHON_DOWNLOAD_URL=http://downloads.sourceforge.net/project/wxpython/wxPython/$WXPYTHON_VERSION/$WXPYTHON_SOURCE_DIRECTORY.tar.bz2

BUILD_DIRECTORY=$SCRIPT_DIRECTORY/build
PREFIX_DIRECTORY=$SCRIPT_DIRECTORY/output
PACKAGE_DIRECTORY=$SCRIPT_DIRECTORY/package
SOURCE_DIRECTORY=$SCRIPT_DIRECTORY/src
ARCHIVE_DIRECTORY=$SCRIPT_DIRECTORY/archive
PATCH_DIRECTORY=$SCRIPT_DIRECTORY/patches

print_usage()
{

	if [ "$1" != "" ]; then
		echo ""
		echo "`tput bold`Unknown option $1.`tput sgr0`"
		echo ""
	fi

	echo "usage: build.sh [-a|--arch <architecture_string>] [-c|--cpus <cpu_count>] [-d|--debug] [-h|--help]"
	echo ""
	echo "-a / --arch <architecture_string>: specify an architecture to build. You can specify"
	echo "                                   multiple instaces of this argument to specify multiple architectures. If this argument"
	echo "                                   is not specified the script will build a universal i386 and x86_64 application."
	echo ""
	echo "-c / --cpus <cpu_count>: specify the number of CPUs (or cores) in your system. The"
	echo "                         build script will spawn twice at much build threads so that your system is optimally"
	echo "                         used."
	echo ""
	echo "-d / --debug: build a debug configuration binary."
	echo ""
	echo "-h / --help: show help text."
	echo ""
	echo "-s / --steps: <steps>: Select which steps to execute, either a single step number in the range [1-8] or a comma separated"
	echo "                       list of steps or a step number followed by a comma followed by "..." ( eg. 3,... ). The later"
	echo "                       syntax executes the step provided plus the following steps up until the last."
	echo ""

	if [ "$1" != "" ]; then
		exit 1
	else
		exit 0
	fi

}

mrproper()
{

	rm -rdf build build-debug output output-debug package package-debug
	exit

}

while [ "$1" != "" ]; do

	case $1 in

		# This flag allow the user to specify a target architcture. There can be multiple occurences of this flag with different architectures.
		-a | --arch )
		shift
		if [ "$1" == ppc ] || [ "$1" == i386 ] || [ "$1" == x86_64 ]; then
			BUILD_ARCHITECTURES+=( $1 )
		else
			echo "Unknown architecture `tput bold`'$1'`tput sgr0`"
			exit 1
		fi
		;;

		# With this flag the user can supply the ammount of CPUs (cores) in his/her system
		-c | --cpus )
		shift
		CPU_COUNT=$1
		;;

		# The user might select a debug build via this flag
		-d | --debug )
		BUILD_TYPE=Debug
		;;

		# Print the help text
		-h | --help )
		print_usage
		;;

		# clean all build products
		-m | --mrproper )
		mrproper
		;;

		# Select which steps to execute, either a single step number in the range [1-8] or a comma separated list of steps
		# or a step number followed by a comma followed by "..." ( eg. 3,... ). The later syntax executes the step provided
		# plus the following steps up until the last.

		-s | --steps )
		shift
		IFS=',' read -a STEPS <<< "$1"

		if [ ${#STEPS[*]} == 0 ]; then
			echo "Error: The option '-s' requires at least one value to be passed!"
			exit 1
		fi

		for STEP in ${STEPS[@]}
		do
			if [ $STEP != "..." ] && [ $STEP -gt 0 ] && [ $STEP -lt 9 ]; then
				BUILD_STEPS+=( $STEP )
			elif [ $STEP == "..." ]; then

				if [ ${#BUILD_STEPS[*]} == 0 ]; then
					echo "Error: '...' specified for -s without prior step number! "
					exit 1
				fi

				LAST_STEP=${BUILD_STEPS[${#BUILD_STEPS[*]} - 1]}

				for (( STEP_TO_ADD = ${BUILD_STEPS[${#BUILD_STEPS[*]} - 1]} + 1; STEP_TO_ADD <= 8; STEP_TO_ADD++ ))
				do
					BUILD_STEPS+=($STEP_TO_ADD)
				done

			else
				echo "Error: Step number '$STEP' out of range 1-8"
				exit 1
			fi
		done
		;;

		# "Catch-all" case for unrecognized commandline options
		* )
		print_usage $1

	esac

	shift

done


init()
{

	if [ ${#BUILD_ARCHITECTURES[@]} == 0 ]; then
		BUILD_ARCHITECTURES=( i386 x86_64 )
	fi

	if [ ${#BUILD_STEPS[@]} == 0 ]; then
		BUILD_STEPS=( 1 2 3 4 5 6 7 8 )
	fi

	MAKE_THREAD_COUNT=-j$(($CPU_COUNT*2)) # use twice as many threads as CPUs (cores) are in the system

	mkdir -p $BUILD_DIRECTORY
	mkdir -p $PREFIX_DIRECTORY
	mkdir -p $PACKAGE_DIRECTORY
	mkdir -p $ARCHIVE_DIRECTORY
	mkdir -p $SOURCE_DIRECTORY

	if [ $BUILD_TYPE = Debug ]; then
		WXWIDGETS_ADDITIONAL_FLAGS=--enable-debug
		KICAD_BUILD_FLAGS="-DCMAKE_BUILD_TYPE=Debug"
		BUILD_DIRECTORY=$BUILD_DIRECTORY-debug
		PREFIX_DIRECTORY=$PREFIX_DIRECTORY-debug
		PACKAGE_DIRECTORY=$PACKAGE_DIRECTORY-debug
		REVISION_APPENDIX=-debug
	fi

}

main()
{

	init

	case $BUILD_TYPE in
		Release ) echo "BUILDING RELEASE BINARIES"
			  ;;
		Debug )   echo "BUILDING DEBUG BINARIES"
	            	  ;;
	esac

	for STEP in ${BUILD_STEPS[*]}
	do
		step$STEP
	done

}

exit_on_install_error()
{

	echo "install error on $STEP_NAME  STEP: $STEP_NUMBER"
	exit 1

}

exit_on_build_error()
{

	echo "build error on $STEP_NAME  STEP: $STEP_NUMBER"
	exit 2

}

print_step_starting_message()
{

	echo ""
	echo ""
	echo "****************************************************************************"
	echo "Starting step: $STEP_NAME"
	echo "****************************************************************************"
	echo ""
	echo ""

}

step1()
{

	unpack_patch_wxpython()
	{
		cd $SOURCE_DIRECTORY
		echo "unpacking wxpython sources ..."
		tar xfj $ARCHIVE_DIRECTORY/$WXPYTHON_SOURCE_DIRECTORY.tar.bz2 || exit_on_build_error
		cd $WXPYTHON_SOURCE_DIRECTORY
		echo "patching wxpython sources ..."
		patch -p1 < $PATCH_DIRECTORY/wxpython-${WXPYTHON_VERSION}-kicad.patch || exit_on_build_error
		patch -p1 < $PATCH_DIRECTORY/wxwidgets-${WXPYTHON_VERSION}_filehistory_osx.patch || exit_on_build_error
		cd $SCRIPT_DIRECTORY
	}

	STEP_NAME="CHECK & UNPACK WXPYTHON ($WXPYTHON_SOURCE_DIRECTORY)"
	STEP_NUMBER=1

	print_step_starting_message

	test -f $ARCHIVE_DIRECTORY/$WXPYTHON_SOURCE_DIRECTORY.tar.bz2 || curl -L $WXPYTHON_DOWNLOAD_URL -o $ARCHIVE_DIRECTORY/$WXPYTHON_SOURCE_DIRECTORY.tar.bz2 || exit_on_build_error
	test -d $SOURCE_DIRECTORY/$WXPYTHON_SOURCE_DIRECTORY || unpack_patch_wxpython

}

step2()
{

	if [ -d $SOURCE_DIRECTORY/$KICAD_DIRECTORY ]; then
	  STEP_NAME="GET KICAD SOURCES"
	else
	  STEP_NAME="UPDATE KICAD SOURCES"
	fi

	STEP_NUMBER=2
	print_step_starting_message

	test -d $SOURCE_DIRECTORY/$KICAD_DIRECTORY || (cd $SOURCE_DIRECTORY; bzr branch $KICAD_BRANCH kicad ; cd ..) || exit_on_build_error
	test -d $SOURCE_DIRECTORY/$KICAD_DIRECTORY && (cd $SOURCE_DIRECTORY/$KICAD_DIRECTORY; bzr pull; cd ..) || exit_on_build_error

	test -d $SOURCE_DIRECTORY/$LIBRARY_DIRECTORY || (cd $SOURCE_DIRECTORY; bzr branch lp:~kicad-lib-committers/kicad/library ; cd ..) || exit_on_build_error
	test -d $SOURCE_DIRECTORY/$LIBRARY_DIRECTORY && (cd $SOURCE_DIRECTORY/$LIBRARY_DIRECTORY; bzr pull; cd ..) || exit_on_build_error

    cd $SOURCE_DIRECTORY/$KICAD_DIRECTORY
    echo "patching kicad sources ..."
    patch -p1 -N < $PATCH_DIRECTORY/kicad_misc.patch 

}

step3()
{

	STEP_NAME="BUILD WXWIDGETS"
	STEP_NUMBER=3
	print_step_starting_message

	mkdir -p $BUILD_DIRECTORY/$WXPYTHON_SOURCE_DIRECTORY
	cd $BUILD_DIRECTORY/$WXPYTHON_SOURCE_DIRECTORY

	IFS_OLD=$IFS
	IFS=,
	UNIVERSAL_BINARY_STRING="${BUILD_ARCHITECTURES[*]}"
	IFS=$IFS_OLD

	test -f Makefile ||  $SOURCE_DIRECTORY/$WXPYTHON_SOURCE_DIRECTORY/configure  --disable-debug            \
	                                                                             --prefix=$PREFIX_DIRECTORY \
	                                                                             --enable-unicode	  	\
	                                                                             --enable-std_string   	\
	                                                                             --enable-display		\
	                                                                             --with-opengl		\
	                                                                             --with-osx_cocoa		\
	                                                                             --with-libjpeg		\
	                                                                             --with-libtiff		\
	                                                                             --with-libpng		\
	                                                                             --with-zlib		\
	                                                                             --enable-dnd		\
	                                                                             --enable-clipboard		\
	                                                                             --enable-webkit		\
	                                                                             --enable-monolithic	\
	                                                                             --enable-svg               \
	                                                                             --with-expat		\
	                                                                             --enable-universal-binary="${UNIVERSAL_BINARY_STRING}" \
	                                                                             $WXWIDGETS_ADDITIONAL_FLAGS || exit_on_build_error


	make $MAKE_THREAD_COUNT || exit_on_build_error
	make install || exit_on_build_error
	cd $SCRIPT_DIRECTORY

}

step4()
{

	STEP_NAME="BUILD WXPYTHON PYTHON EXTENSIONS"
	STEP_NUMBER=4
	print_step_starting_message

	PY_OPTS="WXPORT=osx_cocoa UNICODE=1 INSTALL_MULTIVERSION=1 BUILD_GLCANVAS=1 BUILD_GIZMOS=1 BUILD_STC=1"

	cd $SOURCE_DIRECTORY/$WXPYTHON_SOURCE_DIRECTORY/wxPython

	python setup.py build_ext  WX_CONFIG=$PREFIX_DIRECTORY/bin/wx-config $PY_OPTS  || exit_on_build_error

	python setup.py install --prefix=$PREFIX_DIRECTORY  WX_CONFIG=$PREFIX_DIRECTORY/bin/wx-config  $PY_OPTS || exit_on_build_error

	cd $SCRIPT_DIRECTORY

}

step5()
{

	STEP_NAME="BUILD KICAD"
	STEP_NUMBER=5
	print_step_starting_message

	export PATH=$PREFIX_DIRECTORY/bin:$PATH
	export wxWidgets_ROOT_DIR=$PREFIX_DIRECTORY

	mkdir -p $BUILD_DIRECTORY/$KICAD_DIRECTORY
	cd $BUILD_DIRECTORY/$KICAD_DIRECTORY

	mkdir -p $PREFIX_DIRECTORY/python/site-packages

	CMAKE_ARCHITECTURE_STRING=
        CMAKE_ASM_FLAGS=

	for ARCHITECTURE in "${BUILD_ARCHITECTURES[@]}"
	do
		CMAKE_ARCHITECTURE_STRING=$CMAKE_ARCHITECTURE_STRING"${ARCHITECTURE};"
                CMAKE_ASM_FLAGS=$CMAKE_ASM_FLAGS" -arch ${ARCHITECTURE}"
	done
	CMAKE_ARCHITECTURE_STRING=${CMAKE_ARCHITECTURE_STRING%;}

	cmake $SOURCE_DIRECTORY/$KICAD_DIRECTORY -DKICAD_SCRIPTING=ON                                              \
	                                         -DKICAD_SCRIPTING_MODULES=ON                                      \
	                                         -DKICAD_SCRIPTING_WXPYTHON=ON                                     \
	                                         -DCMAKE_CXX_FLAGS=-D__ASSERTMACROS__                              \
                                                 -DCMAKE_ASM_FLAGS="${CMAKE_ASM_FLAGS}"                            \
	                                         -DCMAKE_INSTALL_PREFIX=$PREFIX_DIRECTORY                          \
	                                         -DCMAKE_FIND_FRAMEWORK=LAST                                       \
	                                         -DwxWidgets_CONFIG_EXECUTABLE=$PREFIX_DIRECTORY/bin/wx-config     \
	                                         -DPYTHON_EXECUTABLE=`which python`                                \
	                                         -DPYTHON_SITE_PACKAGE_PATH=$PREFIX_DIRECTORY/python/site-packages \
	                                         -DPYTHON_PACKAGES_PATH=$PREFIX_DIRECTORY/python/site-packages     \
	                                         -DCMAKE_OSX_ARCHITECTURES="${CMAKE_ARCHITECTURE_STRING}"          \
	                                         -DCMAKE_BUILD_TYPE=$BUILD_TYPE

	#dependencies on swig .i files are not well managed, so if we clear this
	#then swig rebuilds the .cxx files
	rm -f $BUILD_DIRECTORY/$KICAD_DIRECTORY/pcbnew/pcbnew_wrap.cxx
	rm -f $BUILD_DIRECTORY/$KICAD_DIRECTORY/pcbnew/scripting/pcbnewPYTHON_wrap.cxx

	make $MAKE_THREAD_COUNT install || exit_on_build_error

	cd $SCRIPT_DIRECTORY

}

step6()
{
	STEP_NAME="INSTALLING LIBRARY"
	STEP_NUMBER=6
	print_step_starting_message

	mkdir -p $BUILD_DIRECTORY/$LIBRARY_DIRECTORY
	cd $BUILD_DIRECTORY/$LIBRARY_DIRECTORY

	cmake $SOURCE_DIRECTORY/$LIBRARY_DIRECTORY/ -DCMAKE_INSTALL_PREFIX=$PREFIX_DIRECTORY              \
	                                            -DKICAD_TEMPLATES=$PREFIX_DIRECTORY/share/kicad/template   \
	                                            -DKICAD_MODULES=$PREFIX_DIRECTORY/share/kicad/modules \
	                                            -DKICAD_LIBRARY=$PREFIX_DIRECTORY/share/kicad/library
	make install
	cd $SCRIPT_DIRECTORY
}

step7()
{
	STEP_NAME="REPACKAGE *.app"
	STEP_NUMBER=7
	print_step_starting_message

	INSTALL_NAME_TOOL="xcrun install_name_tool"
	KICAD_FRAMEWORKS_PATH="@executable_path/../../../kicad.app/Contents/Frameworks/"

	PYTHON_SITE_PKGS=$PREFIX_DIRECTORY/bin/kicad.app/Contents/Frameworks/python2.7/site-packages
	mkdir -p $PYTHON_SITE_PKGS

	FRAMEWORK_LIBS=$PREFIX_DIRECTORY/bin/kicad.app/Contents/Frameworks/

	PCBNEW_EXES=$PREFIX_DIRECTORY/bin/pcbnew.app/Contents/MacOS
	KICAD_EXES=$PREFIX_DIRECTORY/bin/kicad.app/Contents/MacOS

	echo "copying kicad libs"
	cp $BUILD_DIRECTORY/$KICAD_DIRECTORY/pcbnew/_pcbnew.so 	     $PYTHON_SITE_PKGS
	cp $BUILD_DIRECTORY/$KICAD_DIRECTORY/pcbnew/pcbnew.py  	     $PYTHON_SITE_PKGS

	cp -RfP $PREFIX_DIRECTORY/lib/libwx_osx_cocoau-${WXPYTHON_VERSION}.0.dylib $FRAMEWORK_LIBS
	cp -RfP $PREFIX_DIRECTORY/lib/libwx_osx_cocoau_gl-${WXPYTHON_VERSION}.0.dylib $FRAMEWORK_LIBS

	cd $FRAMEWORK_LIBS
	ln -s libwx_osx_cocoau-${WXPYTHON_VERSION}.0.dylib libwx_osx_cocoau-${WXPYTHON_VERSION_MAJOR}.dylib
	ln -s libwx_osx_cocoau-${WXPYTHON_VERSION}.0.dylib libwx_osx_cocoau-${WXPYTHON_VERSION_MAJOR}.${WXPYTHON_VERSION_MINOR}.dylib

	ln -s libwx_osx_cocoau_gl-${WXPYTHON_VERSION}.0.dylib libwx_osx_cocoau_gl-${WXPYTHON_VERSION_MAJOR}.dylib
	ln -s libwx_osx_cocoau_gl-${WXPYTHON_VERSION}.0.dylib libwx_osx_cocoau_gl-${WXPYTHON_VERSION_MAJOR}.${WXPYTHON_VERSION_MINOR}.dylib

	$INSTALL_NAME_TOOL -id $KICAD_FRAMEWORKS_PATH/libwx_osx_cocoau-${WXPYTHON_VERSION}.0.dylib $FRAMEWORK_LIBS/libwx_osx_cocoau-${WXPYTHON_VERSION}.0.dylib
	$INSTALL_NAME_TOOL -id $KICAD_FRAMEWORKS_PATH/libwx_osx_cocoau_gl-${WXPYTHON_VERSION}.0.dylib $FRAMEWORK_LIBS/libwx_osx_cocoau_gl-${WXPYTHON_VERSION}.0.dylib
	$INSTALL_NAME_TOOL -change $PREFIX_DIRECTORY/lib/libwx_osx_cocoau-${WXPYTHON_VERSION}.0.dylib $KICAD_FRAMEWORKS_PATH/libwx_osx_cocoau-${WXPYTHON_VERSION}.0.dylib $FRAMEWORK_LIBS/libwx_osx_cocoau_gl-${WXPYTHON_VERSION}.0.dylib

	cd $SCRIPT_DIRECTORY
	cp -rf $PREFIX_DIRECTORY/lib/python2.7/site-packages/wx-${WXPYTHON_VERSION_MAJOR}.${WXPYTHON_VERSION_MINOR}-osx_cocoa/wx   $PYTHON_SITE_PKGS

	for APP in bitmap2component eeschema gerbview pcbnew pcb_calculator kicad cvpcb
	do
		echo repackaging $APP
		cp -fP $BUILD_DIRECTORY/$KICAD_DIRECTORY/$APP/$APP.app/Contents/MacOS/$APP $PREFIX_DIRECTORY/bin/$APP.app/Contents/MacOS/$APP.bin
		cp -fP $SCRIPT_DIRECTORY/patches/loader.sh $PREFIX_DIRECTORY/bin/$APP.app/Contents/MacOS/$APP
		chmod a+x $PREFIX_DIRECTORY/bin/$APP.app/Contents/MacOS/$APP

		echo "fixing references in $APP"
		$INSTALL_NAME_TOOL -change $PREFIX_DIRECTORY/lib/libwx_osx_cocoau_gl-${WXPYTHON_VERSION_MAJOR}.dylib $KICAD_FRAMEWORKS_PATH/libwx_osx_cocoau_gl-${WXPYTHON_VERSION_MAJOR}.dylib $PREFIX_DIRECTORY/bin/$APP.app/Contents/MacOS/$APP.bin
		$INSTALL_NAME_TOOL -change $PREFIX_DIRECTORY/lib/libwx_osx_cocoau-${WXPYTHON_VERSION_MAJOR}.dylib $KICAD_FRAMEWORKS_PATH/libwx_osx_cocoau-${WXPYTHON_VERSION_MAJOR}.dylib $PREFIX_DIRECTORY/bin/$APP.app/Contents/MacOS/$APP.bin
	done

	echo "fixing references in wxPython libs"

	find $PREFIX_DIRECTORY -name "*.so" -exec $INSTALL_NAME_TOOL -change $PREFIX_DIRECTORY/lib/libwx_osx_cocoau-${WXPYTHON_VERSION_MAJOR}.dylib $KICAD_FRAMEWORKS_PATH/libwx_osx_cocoau-${WXPYTHON_VERSION_MAJOR}.dylib {} \;
	find $PREFIX_DIRECTORY -name "*.so" -exec $INSTALL_NAME_TOOL -change $PREFIX_DIRECTORY/lib/libwx_osx_cocoau_gl-${WXPYTHON_VERSION_MAJOR}.dylib $KICAD_FRAMEWORKS_PATH/libwx_osx_cocoau_gl-${WXPYTHON_VERSION_MAJOR}.dylib {} \;

	cd $SCRIPT_DIRECTORY
}

step8()
{

	STEP_NAME="make a zip with all the apps"
	STEP_NUMBER=8
	print_step_starting_message

	rm -rf $PACKAGE_DIRECTORY
	mkdir -p $PACKAGE_DIRECTORY/KiCad/data/scripting/plugins
	echo "copying apps"
	cp -RfP $PREFIX_DIRECTORY/bin/*.app $PACKAGE_DIRECTORY/KiCad
	cp patches/python $PACKAGE_DIRECTORY/KiCad
	echo "copying kicad data"
	cp -rf $PREFIX_DIRECTORY/share/kicad/* $PACKAGE_DIRECTORY/KiCad/data
	cp -rf $SOURCE_DIRECTORY/kicad/pcbnew/scripting/plugins/* $PACKAGE_DIRECTORY/KiCad/data/scripting/plugins
	cp -rf $PATCH_DIRECTORY/python $PACKAGE_DIRECTORY/KiCad/
        REVNO=`cd $SOURCE_DIRECTORY/kicad; bzr revno`
	cd $PACKAGE_DIRECTORY
	zip -r -y kicad-scripting-osx-$REVNO$REVISION_APPENDIX.zip KiCad/*
	cd $SCRIPT_DIRECTORY

}

main

echo "Done!! :-)"
