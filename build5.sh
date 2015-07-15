#!/bin/sh

MYTARG="aarch64-linux"
MYJOBS="-j8"
MYPREF="/opt/cross"
MYCONF="--disable-multilib"
MYBINUTILS="binutils-2.24"
MYGCC="gcc-4.9.2"
MYLINUX="linux-3.17.2"
MYGLIBC="glibc-2.20"
MYMPFR="mpfr-3.1.2"
MYGMP="gmp-6.0.0a"
MYLINUXARCH="arm64"
MYMPC="mpc-1.0.2"
MYISL="isl-0.12"
MYCLOOG="cloog-0.18"
#MYTARG="i586-elf-linux"
#MYTARG="x86_64-elf-linux"
#MYTARG="x86_64-pc-gnu"

get_stuff()
{
#	wget http://ftpmirror.gnu.org/binutils/${MYBINUTILS}.tar.gz
	cp ~/.bldroot/${MYBINUTILS}.tar.bz2 .
	#wget http://ftpmirror.gnu.org/gcc/${MYGCC}/${MYGCC}.tar.gzS
	cp ~/.bldroot/${MYGCC}.tar.bz2 .
	wget https://www.kernel.org/pub/linux/kernel/v3.x/${MYLINUX}.tar.xz
	wget http://ftpmirror.gnu.org/glibc/${MYGLIBC}.tar.xz
#	wget http://ftpmirror.gnu.org/mpfr/${MYMPFR}.tar.xz
	cp ~/.bldroot/${MYMPFR}.tar.xz .
	#wget http://ftpmirror.gnu.org/gmp/${MYGMP}.tar.xz
	cp ~/.bldroot/${MYGMP}.tar.xz .
	#wget http://ftpmirror.gnu.org/mpc/${MYMPC}.tar.gz
	cp ~/.bldroot/${MYMPC}.tar.gz .
	wget ftp://gcc.gnu.org/pub/gcc/infrastructure/${MYISL}.2.tar.bz2
	wget ftp://gcc.gnu.org/pub/gcc/infrastructure/${MYCLOOG}.1.tar.gz 
}
#get_stuff

clean()
{
        sudo rm -rf ${MYBINUTILS} build-binutils build-gcc \
	build-glibc ${MYCLOOG}.1 ${MYGCC}  ${MYGLIBC} gmp-6.0.0 \
	${MYISL}.2  ${MYLINUX}  ${MYMPC} ${MYMPFR} ${MYPREF}/ \
	isl gmp cloog mpc mpfr a.out build-newlib newlib-master logfile.txt
}
clean

unpackstuff()
{
	for f in *.tar*
	do 	tar xf "$f"
	done
}
unpackstuff

makesomelinks()
{
	cd ${MYGCC}
	ln -s ../${MYMPFR} mpfr
	ln -s ../gmp-6.0.0 gmp
	ln -s ../${MYMPC} mpc
	#ln -s ../${MYISL}.2 isl
	#ln -s ../${MYCLOOG}.1 cloog
	cd ..
}
makesomelinks

makesysroot()
{
	sudo mkdir -p ${MYPREF}
	sudo chown $USER ${MYPREF}
}
makesysroot
modifypath()
{
	export PATH=${MYPREF}/bin:$PATH
}
modifypath
binutilsstage()
{
	mkdir build-binutils
	cd build-binutils
	../${MYBINUTILS}/configure \
	--prefix=${MYPREF} \
	--target=${MYTARG} \
	${MYCONF}
	make "${MYJOBS}"
	make install
	cd ..
}
binutilsstage
linuxstage()
{
	# add code to identify ARCH from MYTARG here ..
	cd ${MYLINUX}
	make ARCH=${MYLINUXARCH} INSTALL_HDR_PATH=${MYPREF}/${MYTARG} headers_install
	#make ARCH=x86_64 INSTALL_HDR_PATH=${MYPREF}/${MYTARG} headers_install
	#make INSTALL_HDR_PATH=${MYPREF}/${MYTARG} headers_install
	#make ARCH=i386 INSTALL_HDR_PATH=${MYPREF}/${MYTARG} headers_install
	cd ..
}
linuxstage


gccstage()
{
	mkdir -p build-gcc
	cd build-gcc
	../${MYGCC}/configure \
	--prefix=${MYPREF} \
	--target=${MYTARG} \
	--enable-languages=c,c++ \
	${MYCONF}
	make "${MYJOBS}" all-gcc
	make install-gcc
	cd ..
}
gccstage

clibandheaderstage()
{
	mkdir -p build-glibc
	cd build-glibc
	../${MYGLIBC}/configure \
	--prefix=${MYPREF}/${MYTARG} \
	--build=$MACHTYPE \
	--host=${MYTARG} \
	--target=${MYTARG} \
	--with-headers=${MYPREF}/${MYTARG}/include \
	${MYCONF} libc_cv_forced_unwind=yes

	make install-bootstrap-headers=yes install-headers
	make "${MYJOBS}" csu/subdir_lib
	install csu/crt1.o csu/crti.o csu/crtn.o ${MYPREF}/${MYTARG}/lib
	${MYTARG}-gcc \
	-nostdlib \
	-nostartfiles -shared -x c /dev/null -o ${MYPREF}/${MYTARG}/lib/libc.so
	touch ${MYPREF}/${MYTARG}/include/gnu/stubs.h
	cd ..
}
clibandheaderstage

compiliersupportstage()
{
	cd build-gcc
	make "${MYJOBS}" all-target-libgcc
	make install-target-libgcc
	cd ..  
}
compiliersupportstage

standardclibstage()
{
	cd build-glibc
	make "${MYJOBS}"
	make install
	cd ..
}
standardclibstage

