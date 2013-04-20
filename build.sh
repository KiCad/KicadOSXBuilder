BUILD_TYPE=Release            # Set to the users desired build type
BUILD_ARCHITECTURES=()        # An array to store which architectures will be built
BUILD_ARCHITECTURES_STRING=
CPU_COUNT=4                   # The number of CPUs (core) in the system (defaults to 4)
WXWIDGETS_ADDITIONAL_FLAGS=
REVISION_APPENDIX=

usage()
{

	echo "build.sh [-a arch] [-c cpu_count] [-d] [-h]"

}

# Here comes the parameter parsing. Pretty rudimentary, but it works.

while [ "$1" != "" ]; do
	case $1 in
		-a | --arch )  shift                     # This flag allow the user to specify a target architcture. There can be multiple occurences of this flag with different architectures.
		               BUILD_ARCHITECTURES+=($1)
		               ;;
	       	-c | --cpus )  shift                     # With this flag the user can supply the ammount of CPUs (cores) in his/her system
	       		       CPU_COUNT=$1
	       		       ;;
		-d | --debug ) BUILD_TYPE=Debug          # The user might select a debug build via this flag
		               ;;
		-h | --help )  usage                     # Print the help text
		               exit 0
		               ;;
		* )            usage
		               exit 1
	esac
	shift
done

if [ ${#BUILD_ARCHITECTURES[@]} = 0 ]; then
	BUILD_ARCHITECTURES=( i386 x86_64 )
fi

for ARCHITECTURE in "${BUILD_ARCHITECTURES[@]}"
do
	BUILD_ARCHITECTURES_STRING=$BUILD_ARCHITECTURES_STRING"-arch ${ARCHITECTURE} "
done

MAKE_OPTIONS=-j$(($CPU_COUNT*2)) # use twice as many threads as CPUs (cores) are in the system

WXPYTHON_VERSION=2.9.4.0
WXPYTHON_MAC_OS_VERSION=`sw_vers -productVersion`
WXPYTHON_SOURCE_DIRECTORY=wxPython-src-$WXPYTHON_VERSION
WXPYTHON_DOWNLOAD_URL=http://downloads.sourceforge.net/project/wxpython/wxPython/$WXPYTHON_VERSION/$WXPYTHON_SOURCE_DIRECTORY.tar.bz2

KICAD_DIRECTORY=kicad
LIBRARY_DIRECTORY=library

SCRIPT_DIRECTORY="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

BUILD_DIRECTORY=$SCRIPT_DIRECTORY/build
PREFIX_DIRECTORY=$SCRIPT_DIRECTORY/output
PACKAGE_DIRECTORY=$SCRIPT_DIRECTORY/package
SOURCE_DIRECTORY=$SCRIPT_DIRECTORY/src
ARCHIVE_DIRECTORY=$SCRIPT_DIRECTORY/archive
PATCH_DIRECTORY=$SCRIPT_DIRECTORY/patches

if [ $BUILD_TYPE = Debug ]; then
	WXWIDGETS_ADDITIONAL_FLAGS=--enable-debug
	KICAD_BUILD_FLAGS="-DCMAKE_BUILD_TYPE=Debug"
	BUILD_DIRECTORY=$BUILD_DIR-debug
	PREFIX_DIRECTORY=$PREFIX_DIRECTORY-debug
	PACKAGE_DIRECTORY=$PACKAGE_DIR-debug
	REVISION_APPENDIX=-debug
fi

case $BUILD_TYPE in
	Release ) echo "BUILDING RELEASE BINARIES"
		  ;;
	Debug )   echo "BUILDING DEBUG BINARIES"
            	  ;;
esac

mkdir -p $BUILD_DIRECTORY
mkdir -p $PREFIX_DIRECTORY
mkdir -p $PACKAGE_DIRECTORY
mkdir -p $ARCHIVE_DIRECTORY

exit_on_install_error()
{
	echo "install error on $STEP_NAME  STEP: $STEP_NUMBER"
	exit -1
}

exit_on_build_error()
{
	echo "build error on $STEP_NAME  STEP: $STEP_NUMBER"
	exit -2
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
		patch -p1 < $PATCH_DIRECTORY/wxpython-2.9.4.0-kicad.patch || exit_on_build_error
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

	test -d $SOURCE_DIRECTORY/$KICAD_DIRECTORY || (cd $SOURCE_DIRECTORY; bzr branch lp:kicad ; cd ..) || exit_on_build_error
	test -d $SOURCE_DIRECTORY/$KICAD_DIRECTORY && (cd $SOURCE_DIRECTORY/$KICAD_DIRECTORY; bzr pull; cd ..) || exit_on_build_error

	test -d $SOURCE_DIRECTORY/$LIBRARY_DIRECTORY || (cd $SOURCE_DIRECTORY; bzr branch lp:~kicad-lib-committers/kicad/library ; cd ..) || exit_on_build_error
	test -d $SOURCE_DIRECTORY/$LIBRARY_DIRECTORY && (cd $SOURCE_DIRECTORY/$LIBRARY_DIRECTORY; bzr pull; cd ..) || exit_on_build_error

}

step3()
{

	STEP_NAME="BUILD WXWIDGETS"
	STEP_NUMBER=3
	print_step_starting_message

	mkdir -p $BUILD_DIRECTORY/$WXPYTHON_SOURCE_DIRECTORY
	cd $BUILD_DIRECTORY/$WXPYTHON_DIR

	export OSX_ARCH_OPTS=$BUILD_ARCHITECTURES_STRING

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
	                                                                             --enable-universal-binary  \
	                                                                             $WXWIDGETS_ADDITIONAL_FLAGS || exit_on_build_error


	make $MAKE_OPTIONS || exit_on_build_error
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

	for ARCHITECTURE in "${BUILD_ARCHITECTURES[@]}"
	do
		CMAKE_ARCHITECTURE_STRING=$CMAKE_ARCHITECTURE_STRING"${ARCHITECTURE} -arch "
	done
	CMAKE_ARCHITECTURE_STRING=${CMAKE_ARCHITECTURE_STRING% -arch }

	cmake $SOURCE_DIRECTORY/$KICAD_DIRECTORY -DKICAD_TESTING_VERSION=ON                                        \
                                         	 -DKICAD_SCRIPTING=ON                                              \
                                         	 -DKICAD_SCRIPTING_MODULES=ON                                      \
                                         	 -DKICAD_SCRIPTING_WXPYTHON=ON                                     \
                                         	 -DCMAKE_CXX_FLAGS=-D__ASSERTMACROS__                              \
                                         	 -DCMAKE_INSTALL_PREFIX=$PREFIX_DIRECTORY                          \
                                         	 -DCMAKE_FIND_FRAMEWORK=LAST                                       \
                                          	 -DwxWidgets_CONFIG_EXECUTABLE=$PREFIX_DIRECTORY/bin/wx-config     \
                                         	 -DPYTHON_EXECUTABLE=`which python`                                \
                                         	 -DPYTHON_SITE_PACKAGE_PATH=$PREFIX_DIRECTORY/python/site-packages \
                                         	 -DPYTHON_PACKAGES_PATH=$PREFIX_DIRECTORY/python/site-packages     \
                                         	 -DCMAKE_OSX_ARCHITECTURES=$CMAKE_ARCHITECTURE_STRING              \
                                         	 -DCMAKE_BUILD_TYPE=$BUILD_TYPE

	#dependencies on swig .i files are not well managed, so if we clear this
	#then swig rebuilds the .cxx files
	rm $BUILD_DIRECTORY/$KICAD_DIRECTORY/pcbnew/pcbnew_wrap.cxx
	rm $BUILD_DIRECTORY/$KICAD_DIRECTORY/pcbnew/scripting/pcbnewPYTHON_wrap.cxx

	make $MAKE_OPTIONS install || exit_on_build_error

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
                                              -DKICAD_TEMPLATES=$PREFIX_DIR/share/kicad/templates   \
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
	
	mkdir -p $PREFIX_DIRECTORY/bin/kicad.app/Contents/Frameworks/python2.7/site-packages

	PYTHON_SITE_PKGS=$PREFIX_DIRECTORY/bin/kicad.app/Contents/Frameworks/python2.7/site-packages
	FRAMEWORK_LIBS=$PREFIX_DIRECTORY/bin/kicad.app/Contents/Frameworks/
	
	PCBNEW_EXES=$PREFIX_DIRECTORY/bin/pcbnew.app/Contents/MacOS
	KICAD_EXES=$PREFIX_DIRECTORY/bin/kicad.app/Contents/MacOS

	echo "copying kicad libs"
	cp $BUILD_DIRECTORY/$KICAD_DIRECTORY/pcbnew/_pcbnew.so 								$PYTHON_SITE_PKGS
	cp $BUILD_DIRECTORY/$KICAD_DIRECTORY/pcbnew/pcbnew.py  								$PYTHON_SITE_PKGS
	cp -rfp $PREFIX_DIRECTORY/lib/libwx*2.9.dylib 			 					$FRAMEWORK_LIBS
	cd $FRAMEWORK_LIBS
	ln -s libwx_osx_cocoau-2.9.dylib libwx_osx_cocoau-2.9.4.0.0.dylib
	cd $SCRIPT_DIRECTORY
	cp -rfp $PREFIX_DIRECTORY/lib/python2.7/site-packages/wx-2.9.4-osx_cocoa/wx   $PYTHON_SITE_PKGS


	for APP in bitmap2component eeschema gerbview pcbnew pcb_calculator kicad cvpcb 
	do
		echo repackaging $APP
		cp -rfp $BUILD_DIRECTORY/$KICAD_DIRECTORY/$APP/$APP.app/Contents/MacOS/$APP $PREFIX_DIRECTORY/bin/$APP.app/Contents/MacOS/$APP.bin
		cp -rfp $SCRIPT_DIRECTORY/patches/loader.sh $PREFIX_DIRECTORY/bin/$APP.app/Contents/MacOS/$APP
		chmod a+x $PREFIX_DIRECTORY/bin/$APP.app/Contents/MacOS/$APP
	done


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
	cp -rfp $PREFIX_DIRECTORY/bin/*.app $PACKAGE_DIRECTORY/KiCad
	cp patches/python $PACKAGE_DIR/KiCad
	echo "copying kicad data"
	cp -rfp $PREFIX_DIRECTORY/share/kicad/* $PACKAGE_DIRECTORY/KiCad/data
	cp -rfp $SOURCE_DIRECTORY/kicad/pcbnew/scripting/plugins/* $PACKAGE_DIRECTORY/KiCad/data/scripting/plugins
	REVNO=`cd $SOURCE_DIRECTORY/kicad; bzr revno`
	cd $PACKAGE_DIRECTORY
	zip -r kicad-scripting-osx-$REVNO$REVISION_APPENDIX.zip KiCad/*
	cd $DIR

}

step1 step2 step3 step4 step5 step6 step7 step8

echo "Done!! :-)"
