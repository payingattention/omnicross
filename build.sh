#!/bin/sh

set -ex

# aarch64
	#MYTARG="aarch64-linux"
	#MYLINUXARCH="arm64"

# i586
	#MYTARG="i586-linux"
	#MYLINUXARCH="x86"

# x86_64
	MYTARG="x86_64-linux"
	MYLINUXARCH="x86_64" 

MYPREF="$(pwd)/toolchain/"
MYSRC="$(pwd)/src" 
MYBINUTILS="binutils-2.25"
MYGCC="gcc-4.9.2"
MYGMP="gmp-6.0.0"
MYMPC="mpc-1.0.2"
MYMPFR="mpfr-3.1.2" 
MYSTARTDIR="$(pwd)"
MYJOBS="-j4"
#MYLANGS="c,c++" 
MYLANGS="c"
MYLINUX="kernel-headers-3.12.6-5" 
MYCONF="--disable-multilib --with-multilib-list=" 
#MYCONF="--with-multilib-list=mx32"
MYMUSL="musl-1.1.6"
MYGLIBC="glibc-2.20" 
MYNEWLIB="newlib-2.2.0"
MYUCLIBC="uClibc-ng-1.0.4"
SUFFIX="tar.xz"


export PATH="${MYPREF}/bin:${PATH}"
mkdir -p ${MYPREF} 


common_obtain_source_code()
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
#common_obtain_source_code

common_clean()
{
        rm -rf ${MYBINUTILS} ${MYGCC} ${MYGLIBC} \
         ${MYLINUX} ${MYMPC} ${MYMPFR} ${MYPREF} ${MYNEWLIB} \
        build-glibc build-binutils build-gcc gmp-6.0.0 isl gmp \
        cloog mpc mpfr a.out build-newlib newlib-master logfile.txt
        rm -rf ${MYMUSL} ${MYUCLIBC}
	rm -rf build-uclibc
        rm -rf toolchain/
        rm -rf build-binutils/
        rm -rf musl-build/
        rm -rf build-gcc/
        rm -rf build2-gcc
        rm -rf a.out
}
common_clean 


common_binutils_stage()
{
	tar -xf "${MYSRC}/${MYBINUTILS}.${SUFFIX}"

	mkdir build-binutils
	cd build-binutils
	${MYSTARTDIR}/${MYBINUTILS}/configure \
	--prefix=${MYPREF} \
	--target=${MYTARG} 
	
	make "${MYJOBS}"
	make install
	cd "${MYSTARTDIR}"
}
common_binutils_stage

common_linux_stage()
{ 
	tar -xf "${MYSRC}/${MYLINUX}.${SUFFIX}"
	cd ${MYLINUX}
	make ARCH=${MYLINUXARCH} INSTALL_HDR_PATH=${MYPREF}/${MYTARG} headers_install
	cd "${MYSTARTDIR}"
}
common_linux_stage


common_gcc_stage_one()
{
        tar -xf "${MYSRC}/${MYGCC}.${SUFFIX}"

	# this patch is only needed for musl
        #cd "${MYGCC}"
        #patch -p1 < "${MYSTARTDIR}/patches/${MYGCC}-musl.diff"
        #cd "${MYSTARTDIR}"

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
common_gcc_stage_one

glibc_stage()
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


	cd build-gcc
	make "${MYJOBS}" all-target-libgcc
	make install-target-libgcc
	cd "${MYSTARTDIR}" 

	cd build-glibc
	make "${MYJOBS}"
	make install 
	cd "${MYSTARTDIR}"
}
#glibc_stage

newlib_stage()
{
	tar -xf "${MYSRC}/${MYNEWLIB}.${SUFFIX}"
	mkdir -p build-newlib
	cd build-newlib 
	${MYSTARTDIR}/${MYNEWLIB}/configure \
        --target="${MYTARG}" \
        --prefix="${MYPREF}" \
	--disable-threads \
	--disable-shared
	#$MYCONF 
	make "${MYJOBS}"
	make install
	cd "${MYSTARTDIR}" 
        #mkdir build2-gcc
        cd build2-gcc
        ${MYSTARTDIR}/${MYGCC}/configure \
        --prefix="$MYPREF" \
        --target=${MYTARG} \
        --enable-languages=${MYLANGS} \
	--disable-threads 
        make "${MYJOBS}"
        make install

        cd "${MYSTARTDIR}" 

}
#newlib_stage
musl_stage()
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
        then    MYCONF="${MYCONF} --disable-shared "
        fi

        mkdir build2-gcc
        cd build2-gcc
        ${MYSTARTDIR}/${MYGCC}/configure \
        --prefix="$MYPREF" \
        --target=${MYTARG} \
        --enable-languages=${MYLANGS} \
        --disable-libmudflap \
        --disable-libsanitizer \
	--disable-nls \
        $MYCONF

        make "${MYJOBS}"
        make install

        cd "${MYSTARTDIR}"
}
musl_stage

uclibc_stage()
{

        # musl
        tar -xf "${MYSRC}/${MYUCLIBC}.${SUFFIX}"

	#mkdir build-uclibc
	#cd build-uclibc
	cd ${MYUCLIBC}
        
        #${MYSTARTDIR}/${MYUCLIBC}/configure \
        #--prefix="${MYPREF}/${MYTARG}" \
        #--enable-debug \
        #--enable-optimize \
        #CROSS_COMPILE="${MYTARG}-" CC="${MYTARG}-gcc"
	#make defconfig
	make menuconfig

       	#KERNEL_SOURCE="${MYPREF}/${MYTARG}" \
	#TARGET_ARCH=x86_64 PREFIX="${MYPREF}/${MYTARG}" \
	#CROSS_COMPILE="${MYTARG}-" \
	#CC="${MYTARG}-gcc" \
	#make "${MYJOBS}"

        make install

        cd "${MYSTARTDIR}"

        # gcc 2
        if [ ! -e "$MYPREF/${MYTARG}/lib/libc.so" ]
        then    MYCONF="${MYCONF} --disable-shared "
        fi

        mkdir build2-gcc
        cd build2-gcc
        ${MYSTARTDIR}/${MYGCC}/configure \
        --prefix="$MYPREF" \
        --target=${MYTARG} \
        --enable-languages=${MYLANGS} \
        --disable-libmudflap \
        --disable-libsanitizer \
        --disable-nls \
        $MYCONF

        make "${MYJOBS}"
        make install

        cd "${MYSTARTDIR}"
}
#uclibc_stage

