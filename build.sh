#!/bin/sh

# aarch64
	#MYTARG="aarch64-linux"
	#MYLINUXARCH="arm64"
# i586
	#MYTARG="i586-linux"
	#MYLINUXARCH="x86"
# x86_64
	MYTARG="x86_64-linux"
	MYLINUXARCH="x86_64"

#set -xe


MYPREF="$(pwd)/toolchain/"
MYSRC="$(pwd)/src" 
MYBINUTILS="binutils-2.25"
MYGCC="gcc-4.9.2"
MYGMP="gmp-6.0.0"
MYMPC="mpc-1.0.2"
MYMPFR="mpfr-3.1.2" 
MYSTARTDIR="$(pwd)"
MYJOBS="-j8"
MYLANGS="c,c++" 
MYLINUX="kernel-headers-3.12.6-5" 
MYCONF="--disable-multilib" #"--disable-multilib --disable-threads --disable-shared" 
MYGLIBC="glibc-2.20" 
SUFFIX="tar.xz"


export PATH="${MYPREF}/bin:${PATH}"

# https://www.kernel.org/pub/linux/kernel/v3.x/${MYLINUX}.tar.xz
obtain_source_code()
{
        GNU_MIRROR="https://ftp.gnu.org/gnu"
        MUSL_MIRROR="http://www.musl-libc.org/releases"
        KERNEL_MIRROR="http://ftp.barfooze.de/pub/sabotage/tarballs/"
        SUFFIX="tar.gz"
        mkdir "${MYSRC}"
        cd "${MYSRC}"
        wget "${MUSL_MIRROR}/${MYLINUX}.${SUFFIX}"
        wget ${KERNEL_MIRROR}/${MYLINUX}.tar.xz
        wget "${GNU_MIRROR}/gmp/${MYGMP}.${SUFFIX}"
        wget "${GNU_MIRROR}/mpfr/${MYMPFR}.${SUFFIX}"
        wget "${GNU_MIRROR}/mpc/${MYMPC}.${SUFFIX}"
        wget "${GNU_MIRROR}/gcc/${MYGCC}/${MYGCC}.${SUFFIX}"
        wget "${GNU_MIRROR}/binutils/${MYBINUTILS}.${SUFFIX}"
        #wget "${GNU_MIRROR}/glibc/${GLIBC_VERSION}.${SUFFIX}" 
        #wget "${NEWLIB_MIRROR}/${NEWLIB_VERSION}.${SUFFIX}"
        cd "${MYSTARTDIR}"
        mkdir patches
        cd patches
        cd "${MYSTARTDIR}"
}
#obtain_source_code

clean()
{
        rm -rf ${MYBINUTILS} ${MYGCC} ${MYGLIBC} \
         ${MYLINUX} ${MYMPC} ${MYMPFR} ${MYPREF} \
        build-glibc build-binutils build-gcc gmp-6.0.0 isl gmp \
        cloog mpc mpfr a.out build-newlib newlib-master logfile.txt
        rm -rf ${MYMUSL}
        rm -rf toolchain/
        rm -rf build-binutils/
        rm -rf musl-build/
        rm -rf build-gcc/
        rm -rf build2-gcc
        rm -rf a.out
}
clean

unpack_components()
{ 
	for MYTARBALL in ${MYSRC}/*.tar*
	do 	tar -xf "$MYTARBALL"
	done
}
#unpack_components

#link_components()
#{
#	cd ${MYGCC}
#	ln -s ../${MYMPFR} mpfr
#	ln -s ../gmp-6.0.0 gmp
#	ln -s ../${MYMPC} mpc 
#	cd "${MYSTARTDIR}"
#}
#link_components

makesysroot()
{
	mkdir -p ${MYPREF} 
}
makesysroot 

binutilsstage()
{
	tar -xf "${MYSRC}/${MYBINUTILS}.${SUFFIX}"

	mkdir build-binutils
	cd build-binutils
	${MYSTARTDIR}/${MYBINUTILS}/configure \
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
	tar -xf "${MYSRC}/${MYLINUX}.${SUFFIX}"
	cd ${MYLINUX}
	make ARCH=${MYLINUXARCH} INSTALL_HDR_PATH=${MYPREF}/${MYTARG} headers_install
	cd "${MYSTARTDIR}"
}
linuxstage 

gccstage()
{
	tar -xf "${MYSRC}/${MYGCC}.${SUFFIX}"

        tar -xf "${MYSRC}/${MYGMP}.${SUFFIX}"
       # mv "${MYGMP}" "${MYGCC}/gmp"
        tar -xf "${MYSRC}/${MYMPFR}.${SUFFIX}"
       # mv "${MYMPFR}" "${MYGCC}/mpfr"
        tar -xf "${MYSRC}/${MYMPC}.${SUFFIX}"
       # mv "${MYMPC}" "${MYGCC}/mpc"
	cd ${MYGCC}
	       ln -s ../${MYMPFR} mpfr
       ln -s ../${MYGMP} gmp
       ln -s ../${MYMPC} mpc
	cd "${MYSTARTDIR}"

	mkdir build-gcc
	cd build-gcc
	${MYSTARTDIR}/${MYGCC}/configure \
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
	tar -xf "${MYSRC}/${MYGLIBC}.${SUFFIX}"
	mkdir -p build-glibc
	cd build-glibc
	${MYSTARTDIR}/${MYGLIBC}/configure \
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
	cd "${MYSTARTDIR}"
}
standardclibstage

