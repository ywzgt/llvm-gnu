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

sed '/m64=/s/lib64/lib/' -i.orig gcc/config/i386/t-linux64
sed '/ld.*-uClibc.so.0/s/0/1/' -i.ori gcc/config/linux.h
patch -Np1 -i ../uClibc-provides-libssp.patch

mkdir -v build
cd build

../configure --prefix=/usr \
	--disable-bootstrap \
	--disable-fixincludes \
	--disable-lib{sanitizer,ssp} \
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
${TARGET}-gcc dummy.c -v -Wl,--verbose &> dummy.log
readelf -l a.out | grep ': /lib'
grep "/lib.*/libc.so" dummy.log
rm dummy.c a.out dummy.log
rm -rf ../../$SRC
