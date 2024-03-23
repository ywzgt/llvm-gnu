#!/bin/bash

SRC="musl"
PV="1.2.5"

. ../envars.sh
wget -nv https://musl.libc.org/releases/$SRC-$PV.tar.gz
tar xf $SRC-$PV.tar.gz
cp .config $SRC-$PV
cd $SRC-$PV

sed -i "s@/lib:/usr/local/lib:/usr/lib@/usr/local/lib${1}32:/usr/lib${1}32@" ldso/dynlink.c
./configure --prefix=/usr --libdir=/usr/lib${1}32
make
make install DESTDIR=$PWD/p
cp -a p /build
