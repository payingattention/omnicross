#!/bin/sh 

set -ex 

# aarch64
        #MYTARG="aarch64-linux"
        #MYLINUXARCH="arm64"

# i586
	MYTARG="i586-linux-musl" 
	MYLINUXARCH="x86" 

# x86_64
	#MYTARG="x86_64-linux-musl"
	#MYLINUXARCH="x86_64"

MYPREF="$(pwd)/toolchain/"
MYSRC="$(pwd)/src/"
MYBINUTILS="binutils-2.25"
MYGCC="gcc-4.9.2" 
MYGMP="gmp-6.0.0"
MYMPC="mpc-1.0.2"
MYMPFR="mpfr-3.1.2" 
MYSTARTDIR="$(pwd)"
MYJOBS="-j8" 
MYLANGS="c" 
MYLINUX="kernel-headers-3.12.6-5" 
MYCONF="--disable-multilib --with-multilib-list="
#MYCONF="--with-multilib-list=mx32" 
MYMUSL="musl-1.1.6" 
MYGLIBC="glibc-2.20"
SUFFIX="tar.xz" 


export PATH="${MYPREF}/bin:${PATH}" 
mkdir -p "${MYPREF}"

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

# binutils 
musl_binutils_stage()
{
	tar -xf "${MYSRC}/${MYBINUTILS}.${SUFFIX}"

	mkdir build-binutils
	cd build-binutils
	${MYSTARTDIR}/${MYBINUTILS}/configure \
        --target=${MYTARG} \
	--prefix="$MYPREF"

	make "${MYJOBS}"
	make install
	
	cd "${MYSTARTDIR}"
}
musl_binutils_stage


# linux headers    headers flipped above first gcc stage
kernelheadersstage()
{
	tar -xf "${MYSRC}/${MYLINUX}.${SUFFIX}"
	cd "${MYLINUX}"
	make headers_install ARCH="${MYLINUXARCH}" INSTALL_HDR_PATH="$MYPREF/${MYTARG}"
	cd "${MYSTARTDIR}"
}
kernelheadersstage 

# gcc stage
gcc_stage_one()
{
	tar -xf "${MYSRC}/${MYGCC}.${SUFFIX}"
	cd "${MYGCC}"
	patch -p1 < "${MYSTARTDIR}/patches/${MYGCC}-musl.diff"
	cd "${MYSTARTDIR}" 
	
	tar -xf "${MYSRC}/${MYGMP}.${SUFFIX}"
        tar -xf "${MYSRC}/${MYMPFR}.${SUFFIX}"
        tar -xf "${MYSRC}/${MYMPC}.${SUFFIX}"

        cd ${MYGCC}
        ln -s ../${MYMPFR} mpfr
        ln -s ../${MYGMP} gmp
        ln -s ../${MYMPC} mpc
        cd "${MYSTARTDIR}" 

	mkdir build-gcc
	cd build-gcc

	${MYSTARTDIR}/${MYGCC}/configure \
	--prefix="$MYPREF" \
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
	$MYCONF

    
	make "${MYJOBS}" CFLAGS="-O0 -g0" CXXFLAGS="-O0 -g0"
        make install

        cd "${MYSTARTDIR}" 

}
gcc_stage_one


# musl stage
muslstage()
{ 

	# musl
	tar -xf "${MYSRC}/${MYMUSL}.${SUFFIX}"

	cd "${MYMUSL}"
        ./configure \
        --prefix="${MYPREF}/${MYTARG}" \
        --enable-debug \
        --enable-optimize \
        CROSS_COMPILE="${MYTARG}-" CC="${MYTARG}-gcc" 

	make "${MYJOBS}"
        make install

        cd "${MYSTARTDIR}"

	# gcc 2
	if [ ! -e "$MYPREF/${MYTARG}/lib/libc.so" ]
	then 	MYCONF="${MYCONF} --disable-shared "
	fi 

	mkdir build2-gcc
	cd build2-gcc
	${MYSTARTDIR}/${MYGCC}/configure \
	--prefix="$MYPREF" \
	--target=${MYTARG} \
	--enable-languages=${MYLANGS} \
	--disable-libmudflap \
	--disable-libsanitizer --disable-nls \
	$MYCONF 

	make "${MYJOBS}"
        make install

        cd "${MYSTARTDIR}"
}
muslstage

