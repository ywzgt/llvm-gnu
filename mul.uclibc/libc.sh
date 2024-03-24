#!/bin/bash

SRC="uClibc-ng"
PV="1.0.46"

. ../envars.sh
wget -nv https://downloads.uclibc-ng.org/releases/$PV/$SRC-$PV.tar.xz
tar xf $SRC-$PV.tar.xz
cp .config $SRC-$PV
cd $SRC-$PV
patch -Np1 -i ../uClibc-add-getentropy-from-musl.patch

sed -i.old "/^UCLIBC_EXTRA_CFLAGS/s/=.*/=\"$CFLAGS $LDFLAGS\"/" .config
timeout 10 make silentoldconfig
diff -u --color .config{.old,} || true

sed -i '/\(libintl\|crypt\).h$/d' Makefile.in
sed -i.ori '/UCLIBC_RUNTIME_PREFIX/s/lib/&32/g' \
	ldso/ldso/dl-elf.c \
	utils/ld{d,config}.c

rm -fv include/{crypt,libintl}.h
make
make utils

make install DESTDIR=$PWD/p
make install_utils DESTDIR=$PWD/p
ln -sv uclibc_nonshared.a p/usr/lib32/libssp_nonshared.a
cp -a p /build
