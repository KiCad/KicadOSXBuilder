
MAC_OS_VERSION=10.7
MAKE_OPTS=-j5

WXPYTHON_DIR=wxPython-src-2.9.4.0
WXPYTHON_URL=http://downloads.sourceforge.net/wxpython/$WXPYTHON_DIR.tar.bz2

KICAD_DIR=kicad

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

BUILD_DIR=$DIR/build
PREFIX_DIR=$DIR/output
SRC_DIR=$DIR/src
ARCHIVE_DIR=$DIR/archive

#WX_DEBUG=--enable-debug



exit_on_install_error()
{
	echo "install error on $STEPNAME  STEP: $STEP"
	exit 1
}

exit_on_build_error()
{
	echo "build error on $STEPNAME  STEP: $STEP"
	exit 1
}





starting()
{
	echo ""
	echo ""
	echo "****************************************************************************"
	echo "Starting step: $STEPNAME"
	echo "****************************************************************************"
	echo ""
	echo ""

}

step1()
{

	unpack_patch_wxpython()
	{
		cd $SRC_DIR 
		echo unpacking wxpython sources .....
		tar xfj ../archive/$WXPYTHON_DIR.tar.bz2 || exit_on_build_error
		cd $WXPYTHON_DIR
		echo patching wxpython sources ....
		patch -p1 < ../../patches/wxpython-2.9.4.0-kicad.patch || exit_on_build_error
		cd ../..  
	}

STEPNAME="CHECK & UNPACK $WXPYTHON_DIR"
STEP=1

starting

test -f $ARCHIVE_DIR/$WXPYTHON_DIR.tar.bz2 || wget $WXPYTHON_URL -O $ARCHIVE_DIR/$WXPYTHON_DIR.tar.bz2 || exit_on_build_error
test -d $SRC_DIR/$WXPYTHON_DIR || unpack_patch_wxpython

}

step2()
{


STEPNAME="GET & UPDATE KICAD DEVEL SOURCES"
STEP=2
starting

test -d $SRC_DIR/kicad || (cd $SRC_DIR; bzr branch lp:kicad ; cd ..) || exit_on_build_error
test -d $SRC_DIR/kicad && (cd $SRC_DIR/kicad; bzr pull; cd ..) || exit_on_build_error

test -d $SRC_DIR/library || (cd $SRC_DIR; bzr branch lp:~kicad-lib-committers/kicad/library ; cd ..) || exit_on_build_error
test -d $SRC_DIR/library && (cd $SRC_DIR/library; bzr pull; cd ..) || exit_on_build_error
}

step3()
{

STEPNAME="BUILD WXWIDGETS FROM SOURCES"
STEP=3
starting
test -d $BUILD_DIR/$WXPYTHON_DIR || mkdir $BUILD_DIR/$WXPYTHON_DIR 
cd $BUILD_DIR/$WXPYTHON_DIR 

export OSX_ARCH_OPTS="-arch i386 -arch x86_64"
test -f Makefile ||  $SRC_DIR/$WXPYTHON_DIR/configure  --disable-debug 		\
								--prefix=$PREFIX_DIR  						\
								--enable-unicode	  						\
								--enable-std_string   						\
							    --enable-display							\
							    --with-opengl								\
							    --with-osx_cocoa							\
							    --with-libjpeg								\
							    --with-libtiff								\
							    --with-libpng								\
							    --with-zlib									\
							    --enable-dnd								\
							    --enable-clipboard							\
							    --enable-webkit								\
							    --enable-monolithic							\
							    --enable-svg								\
							    --with-expat								\
							    --enable-universal-binary                   \
							    $WX_DEBUG									 || exit_on_build_error

#							    --with-macosx-version-min=$MAC_OS_VERSION   || exit_on_build_error


make $MAKE_OPTS || exit_on_build_error
make install || exit_on_build_error
cd ..
}

step4()
{

STEPNAME="BUILD WXPYTHON PYTHON EXTENSIONS"
STEP=4
starting

PY_OPTS="WXPORT=osx_cocoa UNICODE=1 INSTALL_MULTIVERSION=1 BUILD_GLCANVAS=1 BUILD_GIZMOS=1 BUILD_STC=1"

cd $SRC_DIR/$WXPYTHON_DIR/wxPython


python setup.py build_ext  WX_CONFIG=$PREFIX_DIR/bin/wx-config \
							$PY_OPTS  || exit_on_build_error

python setup.py install  --prefix=$PREFIX_DIR  WX_CONFIG=$PREFIX_DIR/bin/wx-config  $PY_OPTS || exit_on_build_error

cd ../..
}

step5()
{

STEPNAME="BUILD KICAD"
STEP=5
starting

export PATH=$PREFIX_DIR/bin:$PATH
export wxWidgets_ROOT_DIR=$PREFIX_DIR

test -d $BUILD_DIR/$KICAD_DIR || mkdir $BUILD_DIR/$KICAD_DIR 
cd $BUILD_DIR/$KICAD_DIR 
mkdir -p $PREFIX_DIR/python/site-packages

 cmake $SRC_DIR/$KICAD_DIR -DKICAD_TESTING_VERSION=ON 	\
						  -DKICAD_SCRIPTING=ON 			\
						  -DKICAD_SCRIPTING_MODULES=ON  \
						  -DKICAD_SCRIPTING_WXPYTHON=ON \
						  -DCMAKE_CXX_FLAGS=-D__ASSERTMACROS__  \
						  -DCMAKE_INSTALL_PREFIX=$PREFIX_DIR \
						  -DCMAKE_BUILD_TYPE=None \
						  -DCMAKE_FIND_FRAMEWORK=LAST \
						  -DwxWidgets_CONFIG_EXECUTABLE=$PREFIX_DIR/bin/wx-config \
						  -DPYTHON_EXECUTABLE=`which python` \
						  -DPYTHON_SITE_PACKAGE_PATH=$PREFIX_DIR/python/site-packages \
						  -DPYTHON_PACKAGES_PATH=$PREFIX_DIR/python/site-packages \
						  -DCMAKE_OSX_ARCHITECTURES="x86_64 -arch i386"

make $MAKE_OPTS install || exit_on_build_error
cd ../..
}

step6()
{
	STEPNAME="Installing libraries"
	STEP=6
	starting

	mkdir -p $BUILD_DIR/library
	cd $BUILD_DIR/library

	cmake $SRC_DIR/library/ -DCMAKE_INSTALL_PREFIX=$PREFIX_DIR \
							-DKICAD_MODULES=$PREFIX_DIR/share/kicad/modules \
							-DKICAD_LIBRARY=$PREFIX_DIR/share/kicad/library
	make install
	cd $DIR
}

step7()
{
	STEPNAME="REPACKAGE *.app"
	STEP=7
	starting
	
	mkdir -p $PREFIX_DIR/bin/kicad.app/Contents/Frameworks/python2.7/site-packages

	PYTHON_SITE_PKGS=$PREFIX_DIR/bin/kicad.app/Contents/Frameworks/python2.7/site-packages
	FRAMEWORK_LIBS=$PREFIX_DIR/bin/kicad.app/Contents/Frameworks/
	
	PCBNEW_EXES=$PREFIX_DIR/bin/pcbnew.app/Contents/MacOS
	KICAD_EXES=$PREFIX_DIR/bin/kicad.app/Contents/MacOS
	


	
	echo "copying kicad libs"
	cp $BUILD_DIR/$KICAD_DIR/pcbnew/_pcbnew.so 								$PYTHON_SITE_PKGS
	cp $BUILD_DIR/$KICAD_DIR/pcbnew/pcbnew.py  								$PYTHON_SITE_PKGS
	cp -rfp $PREFIX_DIR/lib/libwx*2.9.dylib 			 					$FRAMEWORK_LIBS
	cd $FRAMEWORK_LIBS
	ln -s libwx_osx_cocoau-2.9.dylib libwx_osx_cocoau-2.9.4.0.0.dylib
	cd $DIR
	cp -rfp $PREFIX_DIR/lib/python2.7/site-packages/wx-2.9.4-osx_cocoa/wx   $PYTHON_SITE_PKGS


	for APP in bitmap2component eeschema gerbview pcbnew pcb_calculator kicad cvpcb 
	do
		echo repackaging $APP
		cp -rfp $BUILD_DIR/$KICAD_DIR/$APP/$APP.app/Contents/MacOS/$APP   \
			$PREFIX_DIR/bin/$APP.app/Contents/MacOS/$APP.bin
		cp -rfp $DIR/patches/loader.sh  	$PREFIX_DIR/bin/$APP.app/Contents/MacOS/$APP
		chmod a+x $PREFIX_DIR/bin/$APP.app/Contents/MacOS/$APP
	done


	cd $DIR
}

step8()
{
	STEPNAME="make a zip with all the apps"
	STEP=8
	starting
	rm -rf package
	mkdir -p package/KiCad/data
	echo "copying apps"
	cp -rfp $PREFIX_DIR/bin/*.app package/KiCad
	echo "copying kicad data"
	cp -rfp $PREFIX_DIR/share/kicad/* package/KiCad/data
	REVNO=`cd $SRC_DIR/kicad; bzr revno`
	cd package
	zip -r kicad-scripting-osx-$REVNO.zip KiCad/*
	cd $DIR

}


step1
step2
step3
step4
step5
step6
step7
step8

echo "Done!! :-)"
