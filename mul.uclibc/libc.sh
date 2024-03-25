#!/bin/bash

SRC="uClibc-ng"
PV="1.0.46"

. ../envars.sh
wget -nv https://downloads.uclibc-ng.org/releases/$PV/$SRC-$PV.tar.xz
tar xf $SRC-$PV.tar.xz
cp .config $SRC-$PV
cd $SRC-$PV

for i in ../00*.patch; do
	echo "PATCH: ${i##*/}"
	patch -Np1 -i $i
done

sed -i.old "/^UCLIBC_EXTRA_CFLAGS/s/=.*/=\"$CFLAGS $LDFLAGS\"/" .config
timeout 10 make silentoldconfig
diff -u --color .config{.old,} || true

sed -i '/\(libintl\|crypt\).h$/d' Makefile.in
rm -fv include/{crypt,libintl}.h
make
make utils
ar r libssp_noshared.a libc/sysdeps/linux/common/ssp-local.os

make install DESTDIR=$PWD/p
make install_utils DESTDIR=$PWD/p
cp libssp_nonshared.a p/usr/lib32/
cp -a p /build
