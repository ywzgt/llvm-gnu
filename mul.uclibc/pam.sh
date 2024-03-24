#!/bin/bash

SRC="Linux-PAM"
PV="1.6.0"

. ../envars.sh
wget -nv https://github.com/linux-pam/linux-pam/releases/download/v$PV/$SRC-$PV.tar.xz
tar xf $SRC-$PV.tar.xz
cd $SRC-$PV

# 1.6.0 'SIZE_MAX' undeclared
sed '/^#include "argv_parse.h"$/a\#include <stdint.h>' \
	-i modules/pam_namespace/pam_namespace.c

CC="gcc -m32" CXX="g++ -m32" \
./configure --prefix=/usr \
	--sbindir=/usr/sbin \
	--sysconfdir=/etc \
	--libdir=/usr/lib \
	--enable-securedir=/usr/lib/security

make
make install DESTDIR=$PWD/p
