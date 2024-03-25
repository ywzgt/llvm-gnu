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

#patch -Np1 -i ../libc-provides-libssp.patch
sed '/m64=/s/lib64/lib/' -i.ori gcc/config/i386/t-linux64
sed '/ld.*-uClibc.so.0/s/0/1/' -i.ori gcc/config/linux.h

mkdir -v build
cd build

../configure --prefix=/usr \
	--disable-bootstrap \
	--disable-fixincludes \
	--disable-libssp \
	--disable-libsanitizer \
	--enable-multilib \
	--enable-default-pie \
	--enable-default-ssp \
	--enable-languages=c,c++ \
	--with-multilib-list=m64,m32 \
	--with-system-zlib

make
make DESTDIR=$PWD/pkg install
rm -fv pkg/usr/lib/*.la
cp -av pkg/usr/* /usr

echo 'int main(){}' > dummy.c
for abi in 32 64; do
	gcc -m$abi dummy.c -v -Wl,--verbose &> dummy.log
	readelf -l a.out | grep ': /lib'
	grep "/lib.*/libc.so" dummy.log
done
rm dummy.c a.out dummy.log
rm -rf ../../$SRC
