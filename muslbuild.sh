#!/bin/sh 

set -ex
#http://ftp.gnu.org/gnu/binutils/binutils-2.25.tar.bz2
#http://ftp.barfooze.de/pub/sabotage/tarballs/kernel-headers-3.12.6-5.tar.xz



MYPREF="$(pwd)/toolchain" 
MYGMP="gmp-4.3.2"
MYMPC="mpc-0.8.1"
MYMPFR="mpfr-2.4.2"
MYSTARTDIR="$(pwd)"
MYJOBS="-j8" 
ARCH="i586"
MYTARG="$ARCH-linux-musl"
MYLANGS="c" 
MYBINUTILS="binutils-2.25"
MYSRC="$(pwd)/src"
MYGCC="gcc-4.9.2"
MYKERNELHEADERS="kernel-headers-3.12.6-5"
MYMUSL="musl-1.1.6" 
MYLINUXARCH="x86"


CC_PREFIX="${MYPREF}/${MYTARG}" 

export PATH="${CC_PREFIX}/bin:${PATH}" 

MYGCCFLAGS="--disable-multilib --with-multilib-list="
if [ "$ARCH" = "x32" ]
then 	MYGCCFLAGS="--with-multilib-list=mx32"
fi 

# Switch to the CC prefix
PREFIX="$CC_PREFIX"

# sysroot usr 
mkdir -p "${PREFIX}/${MYTARG}"
ln -sf . "${PREFIX}/${MYTARG}/usr"

# binutils 
binutilsstage()
{
	tar -xf "${MYSRC}/${MYBINUTILS}.tar.bz2"

	mkdir build-binutils
	cd build-binutils
	${MYSTARTDIR}/${MYBINUTILS}/configure \
        --target=${MYTARG} \
	--prefix="$PREFIX"

	make "${MYJOBS}"
	make install
	
	cd "${MYSTARTDIR}"
}
binutilsstage

# gcc stage
gcc_stage_one()
{
	tar -xf "${MYSRC}/${MYGCC}.tar.bz2"
	cd "${MYGCC}"
	patch -p1 < "${MYSTARTDIR}/patches/${MYGCC}-musl.diff"
	cd "${MYSTARTDIR}" 

	
	tar -xf "${MYSRC}/${MYGMP}.tar.bz2"
	mv "${MYGMP}" "${MYGCC}/gmp"
	tar -xf "${MYSRC}/${MYMPFR}.tar.bz2"
	mv "${MYMPFR}" "${MYGCC}/mpfr"
	tar -xf "${MYSRC}/${MYMPC}.tar.gz"
	mv "${MYMPC}" "${MYGCC}/mpc"

	mkdir build-gcc
	cd build-gcc

	${MYSTARTDIR}/${MYGCC}/configure \
	--prefix="$PREFIX" \
	--target=${MYTARG} \
	--enable-languages=c \
	--with-newlib \
	--disable-libssp \
	--disable-nls \
	--disable-libquadmath \
	--disable-threads \
	--disable-decimal-float \
	--disable-shared \
	--disable-libmudflap \
	--disable-libgomp \
	--disable-libatomic \
	$MYGCCFLAGS

    
	make "${MYJOBS}" CFLAGS="-O0 -g0" CXXFLAGS="-O0 -g0"
        make install

        cd "${MYSTARTDIR}" 

}
gcc_stage_one

# linux headers 
kernelheadersstage()
{
	tar -xf "${MYSRC}/${MYKERNELHEADERS}.tar.xz"
	cd "${MYKERNELHEADERS}"
	make headers_install ARCH="${MYLINUXARCH}" INSTALL_HDR_PATH="$PREFIX/${MYTARG}"
	cd "${MYSTARTDIR}"
}
kernelheadersstage 

# musl stage
muslstage()
{ 

	tar -xf "${MYSRC}/${MYMUSL}.tar.gz"

	cd "${MYMUSL}"
        ./configure \
        --prefix="${PREFIX}/${MYTARG}" \
        --enable-debug \
        --enable-optimize \
        CROSS_COMPILE="${MYTARG}-" CC="${MYTARG}-gcc" 

	make "${MYJOBS}"
        make install

        cd "${MYSTARTDIR}" 

	#PREFIX="$CC_PREFIX" 


	
	#if [ ! -e "$CC_PREFIX/${MYTARG}/lib/libc.so" ]
	if [ ! -e "$PREFIX/${MYTARG}/lib/libc.so" ]
	then 	MYGCCFLAGS="${MYGCCFLAGS} --disable-shared "
	fi

	# gcc 2
	mkdir build2-gcc
	cd build2-gcc
	${MYSTARTDIR}/${MYGCC}/configure \
	--prefix="$PREFIX" \
	--target=${MYTARG} \
	--enable-languages=${MYLANGS} \
	--disable-libmudflap \
	--disable-libsanitizer --disable-nls \
	$MYGCCFLAGS 

	make "${MYJOBS}"
        make install

        cd "${MYSTARTDIR}"
}
muslstage


