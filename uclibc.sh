#!/bin/bash

set -e
source envars.sh

wget -q https://downloads.uclibc-ng.org/releases/1.0.46/uClibc-ng-1.0.46.tar.xz
tar xf uClibc-ng*xz
cd uClibc-ng-1.0.46
patch -Np1 -i ../patch.sh
cp ../config.sh .config

sed -i.old "/^UCLIBC_EXTRA_CFLAGS/s/=.*/=\"$CFLAGS $LDFLAGS\"/" .config
timeout 10 make silentoldconfig
diff -u .config{.old,} || true

sed -i '/^NONSHARED_LIBNAME/s/uclibc_nonshared.a/lib&/' Rules.mak
sed -i '/\(libintl\|crypt\).h$/d' Makefile.in
rm -fv include/{crypt,libintl}.h
make
make install
