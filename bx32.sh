#!/bin/bash

set -e
source envars.sh

ELIBC=gnu
VERSION=17.0.6
PKG="$PWD/DEST"
URL="https://github.com/llvm/llvm-project"

SRC=(
	${URL}/releases/download/llvmorg-${VERSION}/llvm-${VERSION}.src.tar.xz
	${URL}/releases/download/llvmorg-${VERSION}/cmake-${VERSION}.src.tar.xz
	${URL}/releases/download/llvmorg-${VERSION}/third-party-${VERSION}.src.tar.xz

	${URL}/releases/download/llvmorg-${VERSION}/clang-${VERSION}.src.tar.xz
	${URL}/releases/download/llvmorg-${VERSION}/lld-${VERSION}.src.tar.xz
	${URL}/releases/download/llvmorg-${VERSION}/libunwind-${VERSION}.src.tar.xz

	https://www.linuxfromscratch.org/patches/blfs/svn/clang-17-enable_default_ssp-1.patch
)

for arg in $@; do
	case "$arg" in
		musl)
			ELIBC=musl
			;;
	esac
done

rm -rf *-${VERSION}.src \
    {cmake,third-party,libunwind}
for i in ${SRC[@]}; do
	wget -nv -c $i
	if ! [[ $i =~ BLFS ]]; then
		f=$(basename $i)
		if [[ $f = *.src.tar.xz && ! -d ${f%.tar.xz} ]]
        then
			echo "Extracting $f..."
			tar xf $f &
		fi
	fi
done

while pidof -q tar; do sleep 0.1; done
for i in cmake third-party libunwind
do
    ln -s $i{-${VERSION}.src,}
done
mv ../clang-${VERSION}.src tools/clang
mv ../lld-${VERSION}.src tools/lld

grep -rl '#!.*python' | xargs sed -i '1s/python$/python3/'

if [[ $ELIBC != musl ]]; then
	patch -Np2 -d tools/clang <../clang-17-enable_default_ssp-1.patch
else
	_args=(-DCOMPILER_RT_BUILD_GWP_ASAN=OFF)
fi

src_config() {
	local _flags=(
	 -DCLANG_DEFAULT_LINKER=lld
	 -DCLANG_DEFAULT_OPENMP_RUNTIME=libgomp
	 -DCLANG_DEFAULT_OBJCOPY=llvm-objcopy
	)

	if command -v clang{,++} > /dev/null; then
		CC=clang CXX=clang++ "$@" \
        -DLLVM_USE_LINKER=lld "${_flags[@]}"
	else
		CC=gcc CXX=g++ "$@" \
		-DLLVM_USE_LINKER=gold
	fi
}

src_config \
cmake -DCMAKE_INSTALL_PREFIX=/usr           \
      -DLLVM_ENABLE_FFI=ON                  \
      -DCMAKE_BUILD_TYPE=Release            \
      -DLLVM_BUILD_LLVM_DYLIB=ON            \
      -DLLVM_LINK_LLVM_DYLIB=ON             \
      -DLLVM_ENABLE_RTTI=ON                 \
      -DLLVM_TARGETS_TO_BUILD="host;AMDGPU" \
      -DLLVM_BINUTILS_INCDIR=/usr/include   \
      -DLLVM_INCLUDE_BENCHMARKS=OFF         \
      -DCLANG_DEFAULT_PIE_ON_LINUX=ON       \
      -DLLVM_BUILD_TESTS=OFF \
      -DLLVM_INCLUDE_TESTS=OFF \
      -DLLVM_HOST_TRIPLE=$(gcc -dumpmachine) \
      -DCLANG_CONFIG_FILE_SYSTEM_DIR=/usr/lib/clang \
      -Wno-dev -G Ninja "${_args[@]}" \
      -B build -S llvm-${VERSION}.src

ninja -C build
ninja -C build install
rm -rf $PKG
DESTDIR=$PKG ninja -C build install &> /dev/null

# https://packages.gentoo.org/packages/sys-devel/clang-common
cat > $PKG/usr/lib/clang/clang.cfg <<-EOF
	# It is used to control the default runtimes using by clang.

EOF

ln -s clang.cfg "$PKG/usr/lib/clang/clang++.cfg"
cp $PKG/usr/lib/clang/*.cfg "/usr/lib/clang/"

echo "$VERSION" > $PWD/../../VERSION
clang -v