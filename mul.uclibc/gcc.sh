#!/bin/bash

PKG="gcc"
TRIPLE="$(gcc -dumpmachine)"
TARGET="${TRIPLE/x86_64/i686}"
PV="$(gcc -dumpversion)"
SRC="$PKG-$PV"
SRC_FILE="$SRC.tar.xz"

source ../envars.sh

wget -nv "https://ftp.gnu.org/gnu/gcc/$SRC/$SRC_FILE"
tar xf $SRC_FILE
cd $SRC

#sed '/m64=/s/lib64/lib/' -i.orig
sed 's@m64=.*@m64=../lib@;s@m32=.*@m32=../lib32@;s@mx32=.*@mx32=../libx32@' -i.ori gcc/config/i386/t-linux64
sed '/ld.*-uClibc.so.0/s/0/1/' -i.ori gcc/config/linux.h

#sed -i.ori '1414,$d' libgomp/Makefile.in
#sed -i.ori '1458,$d' libquadmath/Makefile.in

patch -Np1 -i ../uClibc-provides-libssp.patch

wget -nv https://gitweb.gentoo.org/proj/gcc-patches.git/plain/13.2.0/musl/50_all_cpu_indicator.patch \
	https://gitweb.gentoo.org/proj/gcc-patches.git/plain/13.2.0/musl/50_all_posix_memalign.patch \
	https://gitweb.gentoo.org/proj/gcc-patches.git/plain/13.2.0/gentoo/07_all_libiberty-asprintf.patch

patch -p1 -i 07*.patch
patch -p1 -i 50_all_posix_memalign.patch
patch -p1 -i 50_all_cpu_indicator.patch

mkdir -v build
cd build

../configure --prefix=/usr \
	--disable-bootstrap \
	--disable-fixincludes \
	--disable-lib{sanitizer,ssp,gomp,quadmath} \
	--enable-default-pie \
	--enable-default-ssp \
	--enable-multilib \
	--enable-languages=c,c++ \
	--with-multilib-list=m32,m64,mx32 \
	--with-arch=x86-64-v3 \
	--with-system-zlib

make
make DESTDIR=$PWD/pkg install
rm -fv pkg/usr/lib/*.la
cp -av pkg/usr/* /usr

echo 'int main(){}' > dummy.c
for abi in {,x}32 64; do
	gcc -m$abi dummy.c -v -Wl,--verbose &> dummy.log
	readelf -l a.out | grep ': /lib'
	grep "/lib.*/libc.so" dummy.log
done
rm dummy.c a.out dummy.log
rm -rf ../../$SRC
