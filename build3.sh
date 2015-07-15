#!/bin/sh

MYTARG="aarch64-linux"
MYJOBS="-j8"
#MYTARG="i586-elf-linux"
#MYTARG="x86_64-elf-linux"
#MYTARG="x86_64-pc-gnu"

get_stuff()
{
#	wget http://ftpmirror.gnu.org/binutils/binutils-2.24.tar.gz
	cp ~/.bldroot/binutils-2.24.tar.bz2 .
	#wget http://ftpmirror.gnu.org/gcc/gcc-4.9.2/gcc-4.9.2.tar.gzS
	cp ~/.bldroot/gcc-4.9.2.tar.bz2 .
	wget https://www.kernel.org/pub/linux/kernel/v3.x/linux-3.17.2.tar.xz
	wget http://ftpmirror.gnu.org/glibc/glibc-2.20.tar.xz
#	wget http://ftpmirror.gnu.org/mpfr/mpfr-3.1.2.tar.xz
	cp ~/.bldroot/mpfr-3.1.2.tar.xz .
	#wget http://ftpmirror.gnu.org/gmp/gmp-6.0.0a.tar.xz
	cp ~/.bldroot/gmp-6.0.0a.tar.xz .
	#wget http://ftpmirror.gnu.org/mpc/mpc-1.0.2.tar.gz
	cp ~/.bldroot/mpc-1.0.2.tar.gz .
	wget ftp://gcc.gnu.org/pub/gcc/infrastructure/isl-0.12.2.tar.bz2
	wget ftp://gcc.gnu.org/pub/gcc/infrastructure/cloog-0.18.1.tar.gz 
}
#get_stuff

clean()
{
        sudo rm -rf binutils-2.24 build-binutils build-gcc \
	build-glibc cloog-0.18.1 gcc-4.9.2  glibc-2.20 gmp-6.0.0 \
	isl-0.12.2  linux-3.17.2  mpc-1.0.2 mpfr-3.1.2 /opt/cross/ \
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
	cd gcc-4.9.2
	ln -s ../mpfr-3.1.2 mpfr
	ln -s ../gmp-6.0.0 gmp
	ln -s ../mpc-1.0.2 mpc
	#ln -s ../isl-0.12.2 isl
	#ln -s ../cloog-0.18.1 cloog
	cd ..
}
makesomelinks

makesysroot()
{
	sudo mkdir -p /opt/cross
	sudo chown $USER /opt/cross
}
makesysroot
modifypath()
{
	export PATH=/opt/cross/bin:$PATH
}
modifypath
binutilsstage()
{
	mkdir build-binutils
	cd build-binutils
	../binutils-2.24/configure \
	--prefix=/opt/cross \
	--target=$MYTARG \
	--disable-multilib
	make "$MYJOBS"
	make install
	cd ..
}
binutilsstage
linuxstage()
{
	# add code to identify ARCH from MYTARG here ..
	cd linux-3.17.2
	make ARCH=arm64 INSTALL_HDR_PATH=/opt/cross/$MYTARG headers_install
	#make ARCH=x86_64 INSTALL_HDR_PATH=/opt/cross/$MYTARG headers_install
	#make INSTALL_HDR_PATH=/opt/cross/$MYTARG headers_install
	#make ARCH=i386 INSTALL_HDR_PATH=/opt/cross/$MYTARG headers_install
	cd ..
}
linuxstage


gccstage()
{
	mkdir -p build-gcc
	cd build-gcc
	../gcc-4.9.2/configure \
	--prefix=/opt/cross \
	--target=$MYTARG \
	--enable-languages=c,c++ \
	--disable-multilib
	make "$MYJOBS" all-gcc
	make install-gcc
	cd ..
}
gccstage

clibandheaderstage()
{
	mkdir -p build-glibc
	cd build-glibc
	../glibc-2.20/configure \
	--prefix=/opt/cross/$MYTARG \
	--build=$MACHTYPE \
	--host=$MYTARG \
	--target=$MYTARG \
	--with-headers=/opt/cross/$MYTARG/include \
	--disable-multilib libc_cv_forced_unwind=yes

	make install-bootstrap-headers=yes install-headers
	make "$MYJOBS" csu/subdir_lib
	install csu/crt1.o csu/crti.o csu/crtn.o /opt/cross/$MYTARG/lib
	$MYTARG-gcc \
	-nostdlib \
	-nostartfiles -shared -x c /dev/null -o /opt/cross/$MYTARG/lib/libc.so
	touch /opt/cross/$MYTARG/include/gnu/stubs.h
	cd ..
}
clibandheaderstage

compiliersupportstage()
{
	cd build-gcc
	make "$MYJOBS" all-target-libgcc
	make install-target-libgcc
	cd ..  
}
compiliersupportstage

standardclibstage()
{
	cd build-glibc
	make "$MYJOBS"
	make install
	cd ..
}
standardclibstage

