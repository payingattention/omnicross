#!/bin/sh

# aarch64
	#MYTARG="aarch64-linux"
	#MYLINUXARCH="arm64"
# i586
	MYTARG="i586-linux"
	MYLINUXARCH="x86"
# x86_64
	#MYTARG="x86_64-linux"
	#MYLINUXARCH="x86_64"

MYJOBS="-j8"
MYPREF="/opt/cross"
MYCONF="--disable-multilib"
#MYCONF="--disable-multilib --disable-threads --disable-shared"
MYBINUTILS="binutils-2.24"
MYGCC="gcc-4.9.2"
MYLINUX="linux-3.17.2"
MYGLIBC="glibc-2.20"
MYMPFR="mpfr-3.1.2"
MYGMP="gmp-6.0.0a" 
MYMPC="mpc-1.0.2"
MYISL="isl-0.12.2"
MYCLOOG="cloog-0.18.1"

#MYLANGS="c"
MYLANGS="c,c++"

MYSTARTDIR="$(pwd)"

MYSRC="$(pwd)/src"




get_stuff()
{
#	wget http://ftpmirror.gnu.org/binutils/${MYBINUTILS}.tar.gz
	cp src/${MYBINUTILS}.tar.bz2 .
	#wget http://ftpmirror.gnu.org/gcc/${MYGCC}/${MYGCC}.tar.gzS
	cp src/${MYGCC}.tar.bz2 .
	#wget https://www.kernel.org/pub/linux/kernel/v3.x/${MYLINUX}.tar.xz
	cp cp src/${MYLINUX}.tar.xz .
	#wget http://ftpmirror.gnu.org/glibc/${MYGLIBC}.tar.xz
	cp cp src/${MYGLIBC}.tar.xz .
	#wget http://ftpmirror.gnu.org/mpfr/${MYMPFR}.tar.xz
	cp src/${MYMPFR}.tar.xz .
	#wget http://ftpmirror.gnu.org/gmp/${MYGMP}.tar.xz
	cp src/${MYGMP}.tar.xz .
	#wget http://ftpmirror.gnu.org/mpc/${MYMPC}.tar.gz
	cp src/${MYMPC}.tar.gz .
	#wget ftp://gcc.gnu.org/pub/gcc/infrastructure/${MYISL}.tar.bz2
	cp src/${MYISL}.tar.bz2 .
	#wget ftp://gcc.gnu.org/pub/gcc/infrastructure/${MYCLOOG}.tar.gz 
	cp src/${MYCLOOG}.tar.gz .
}
#get_stuff

clean()
{
        sudo rm -rf ${MYBINUTILS} ${MYCLOOG} ${MYGCC}  ${MYGLIBC} \
	${MYISL}  ${MYLINUX}  ${MYMPC} ${MYMPFR} ${MYPREF} \
	build-glibc build-binutils build-gcc  gmp-6.0.0 \
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
	#ln -s ../${MYISL} isl
	#ln -s ../${MYCLOOG} cloog
	cd "${MYSTARTDIR}"
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
	cd "${MYSTARTDIR}"
}
binutilsstage

linuxstage()
{ 
	cd ${MYLINUX}
	make ARCH=${MYLINUXARCH} INSTALL_HDR_PATH=${MYPREF}/${MYTARG} headers_install 
	cd "${MYSTARTDIR}"
}
linuxstage 

gccstage()
{
	mkdir -p build-gcc
	cd build-gcc
	../${MYGCC}/configure \
	--prefix=${MYPREF} \
	--target=${MYTARG} \
	--enable-languages=${MYLANGS} \
        ${MYCONF} 
	make "${MYJOBS}" all-gcc
	make install-gcc
	cd "${MYSTARTDIR}"
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

	# stubs are required
	touch ${MYPREF}/${MYTARG}/include/gnu/stubs.h
	touch ${MYPREF}/${MYTARG}/include/gnu/stubs-32.h
	touch ${MYPREF}/${MYTARG}/include/gnu/stubs-64.h

	cd "${MYSTARTDIR}"
}
clibandheaderstage

compiliersupportstage()
{
	cd build-gcc
	make "${MYJOBS}" all-target-libgcc
	make install-target-libgcc
	cd "${MYSTARTDIR}"
}
compiliersupportstage

standardclibstage()
{
	cd build-glibc
	make "${MYJOBS}"
	make install
	"${MYSTARTDIR}"
	cd "${MYSTARTDIR}"
}
standardclibstage

