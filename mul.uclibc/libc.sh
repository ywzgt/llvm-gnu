#!/bin/bash

SRC="uClibc-ng"
PV="1.0.46"

. ../envars.sh
[[ $1 -eq 64 ]] || rm -fv 003-x86_64-multilib.patch
wget -nv https://downloads.uclibc-ng.org/releases/$PV/$SRC-$PV.tar.xz
tar xf $SRC-$PV.tar.xz

if [[ $1 -eq 64 ]]; then
	rm -fv 003-x86_64-multilib.patch
	cp config-x86_64 $SRC-$PV/.config -v
else
	cp .config $SRC-$PV -v
fi

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
ar r libssp_nonshared.a libc/sysdeps/linux/common/ssp-local.os

if [[ $1 -eq 64 ]]; then
	make install
	make install_utils
	cp libssp_nonshared /usr/lib
else
	make install DESTDIR=$PWD/p
	make install_utils DESTDIR=$PWD/p
	cp libssp_nonshared.a p/usr/lib32/
	cp -a p /build
fi
