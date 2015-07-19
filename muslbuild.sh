#!/bin/sh 

set -ex
# sources (incomplete list):
#http://ftp.gnu.org/gnu/binutils/binutils-2.25.${SUFFIX}
#http://ftp.barfooze.de/pub/sabotage/tarballs/kernel-headers-3.12.6-5.tar.xz 

# i586
	ARCH="i586"
	MYLINUXARCH="x86" 

# x86_64
	#ARCH="x86_64" 
	#MYLINUXARCH="x86_64"

MYPREF="$(pwd)/toolchain/" 
MYGMP="gmp-4.3.2"
MYMPC="mpc-0.8.1"
MYMPFR="mpfr-2.4.2"
MYSTARTDIR="$(pwd)"
MYJOBS="-j8" 
MYTARG="$ARCH-linux-musl"
MYLANGS="c" 
MYBINUTILS="binutils-2.25"
MYSRC="$(pwd)/src/"
MYGCC="gcc-4.9.2"
MYKERNELHEADERS="kernel-headers-3.12.6-5"
MYMUSL="musl-1.1.6"
PREFIX="${MYPREF}/${MYTARG}/" 
SUFFIX="tar.xz"


export PATH="${PREFIX}/bin:${PATH}" 

#MYGCCFLAGS="--disable-multilib --with-multilib-list="
MYGCCFLAGS="--with-multilib-list=mx32"

mkdir -p "${PREFIX}/${MYTARG}"

obtain_source_code()
{
        GNU_MIRROR="https://ftp.gnu.org/gnu"
        MUSL_MIRROR="http://www.musl-libc.org/releases"
        KERNEL_MIRROR="http://ftp.barfooze.de/pub/sabotage/tarballs/" 
        mkdir "${MYSRC}"
        cd "${MYSRC}" 
        wget "${MUSL_MIRROR}/${MYKERNELHEADERS}.${SUFFIX}"
        wget ${KERNEL_MIRROR}/${MYKERNELHEADERS}.tar.xz
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

# binutils 
binutilsstage()
{
	tar -xf "${MYSRC}/${MYBINUTILS}.${SUFFIX}"

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
	tar -xf "${MYSRC}/${MYGCC}.${SUFFIX}"
	cd "${MYGCC}"
	patch -p1 < "${MYSTARTDIR}/patches/${MYGCC}-musl.diff"
	cd "${MYSTARTDIR}" 
	
	tar -xf "${MYSRC}/${MYGMP}.${SUFFIX}"
	mv "${MYGMP}" "${MYGCC}/gmp"
	tar -xf "${MYSRC}/${MYMPFR}.${SUFFIX}"
	mv "${MYMPFR}" "${MYGCC}/mpfr"
	tar -xf "${MYSRC}/${MYMPC}.${SUFFIX}"
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
	tar -xf "${MYSRC}/${MYKERNELHEADERS}.${SUFFIX}"
	cd "${MYKERNELHEADERS}"
	make headers_install ARCH="${MYLINUXARCH}" INSTALL_HDR_PATH="$PREFIX/${MYTARG}"
	cd "${MYSTARTDIR}"
}
kernelheadersstage 

# musl stage
muslstage()
{ 

	# musl
	tar -xf "${MYSRC}/${MYMUSL}.${SUFFIX}"

	cd "${MYMUSL}"
        ./configure \
        --prefix="${PREFIX}/${MYTARG}" \
        --enable-debug \
        --enable-optimize \
        CROSS_COMPILE="${MYTARG}-" CC="${MYTARG}-gcc" 

	make "${MYJOBS}"
        make install

        cd "${MYSTARTDIR}"

	# gcc 2
	if [ ! -e "$PREFIX/${MYTARG}/lib/libc.so" ]
	then 	MYGCCFLAGS="${MYGCCFLAGS} --disable-shared "
	fi 

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

