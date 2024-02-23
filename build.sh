# curl -s https://linuxfromscratch.org/blfs/view/systemd/general/llvm.html | grep -o 'https://.*.\(xz\|patch\)' | uniq

set -e
source envars.sh

SRC=(
	https://github.com/llvm/llvm-project/releases/download/llvmorg-17.0.6/llvm-17.0.6.src.tar.xz
	https://anduin.linuxfromscratch.org/BLFS/llvm/llvm-cmake-17.src.tar.xz
	https://anduin.linuxfromscratch.org/BLFS/llvm/llvm-third-party-17.src.tar.xz
	https://www.linuxfromscratch.org/patches/blfs/svn/clang-17-enable_default_ssp-1.patch
	https://github.com/llvm/llvm-project/releases/download/llvmorg-17.0.6/clang-17.0.6.src.tar.xz
	https://github.com/llvm/llvm-project/releases/download/llvmorg-17.0.6/compiler-rt-17.0.6.src.tar.xz
	https://github.com/llvm/llvm-project/releases/download/llvmorg-17.0.6/lld-17.0.6.src.tar.xz
	https://github.com/llvm/llvm-project/releases/download/llvmorg-17.0.6/libunwind-17.0.6.src.tar.xz
)

# /build/llvm-17.0.6.src/tools/lld/MachO/Target.h:23:10: fatal error: mach-o/compact_unwind_encoding.h: No such file or directory
#    23 | #include "mach-o/compact_unwind_encoding.h"

if [[ $1 = libcxx ]]; then
	SRC+=(
		https://github.com/llvm/llvm-project/releases/download/llvmorg-17.0.6/libcxx-17.0.6.src.tar.xz
		https://github.com/llvm/llvm-project/releases/download/llvmorg-17.0.6/libcxxabi-17.0.6.src.tar.xz
		https://github.com/llvm/llvm-project/releases/download/llvmorg-17.0.6/runtimes-17.0.6.src.tar.xz
	)
fi

for i in ${SRC[@]}; do
	wget -nv -c $i
	if ! [[ $i =~ BLFS ]]; then
		f=$(basename $i)
		if [[ $f = *.src.tar.xz && ! -d ${f%.tar.xz} ]]; then
			echo "Extracting $f..."
			tar xf $f &
		fi
	fi
done

cd llvm-17.0.6.src
tar -xf ../llvm-cmake-17.src.tar.xz
tar -xf ../llvm-third-party-17.src.tar.xz
sed '/LLVM_COMMON_CMAKE_UTILS/s@../cmake@llvm-cmake-17.src@'          \
    -i CMakeLists.txt
sed '/LLVM_THIRD_PARTY_DIR/s@../third-party@llvm-third-party-17.src@' \
    -i cmake/modules/HandleLLVMOptions.cmake

while pidof -q tar; do sleep 0.1; done
mv ../clang-17.0.6.src tools/clang
mv ../lld-17.0.6.src tools/lld
mv ../libunwind-17.0.6.src projects/libunwind
mv ../compiler-rt-17.0.6.src projects/compiler-rt
sed '/^set(LLVM_COMMON_CMAKE_UTILS/d' -i projects/{compiler-rt,libunwind}/CMakeLists.txt

if [[ $1 = libcxx ]]; then
	mv ../libcxx-17.0.6.src projects/libcxx
	mv ../libcxxabi-17.0.6.src projects/libcxxabi
	cp -ri ../runtimes-17.0.6.src/cmake/* llvm-cmake-17.src  # libc++abi testing configuration
	mv ../runtimes-17.0.6.src llvm-runtimes-17.src
	sed '/^set(LLVM_COMMON_CMAKE_UTILS/d' -i llvm-runtimes-17.src/CMakeLists.txt
	sed '/CMAKE_CURRENT_SOURCE_DIR/s@../runtimes@llvm-runtimes-17.src@' \
		-i {projects/lib{cxx{,abi},unwind},runtimes}/CMakeLists.txt
	sed '/^set(LLVM_COMMON_CMAKE_UTILS/d' -i projects/libcxx{,abi}/CMakeLists.txt
	sed 's@../runtimes@llvm-runtimes-17.src@' -i \
		projects/compiler-rt/cmake/Modules/AddCompilerRT.cmake \
		projects/compiler-rt/lib/sanitizer_common/symbolizer/scripts/build_symbolizer.sh
else
	for M in {HandleFlags,WarningFlags}.cmake; do
		if [ ! -e projects/libunwind/cmake/Modules/$M ]; then
			wget -nv -cP projects/libunwind/cmake/Modules \
				https://github.com/llvm/llvm-project/raw/llvmorg-17.0.6/runtimes/cmake/Modules/$M
		fi
	done
fi

grep -rl '#!.*python' | xargs sed -i '1s/python$/python3/'
patch -Np2 -d tools/clang <../clang-17-enable_default_ssp-1.patch
sed 's/clang_dfsan/& -fno-stack-protector/' \
    -i projects/compiler-rt/test/dfsan/origin_unaligned_memtrans.c

mkdir -v build
cd build

src_config() {
	if command -v clang{,++} > /dev/null; then
		if command -v ld.lld > /dev/null; then
			CC=clang CXX=clang++ LD=ld.lld "$@"
		else
			CC=clang CXX=clang++ "$@"
		fi
	else
		CC=gcc CXX=g++ "$@"
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
      -Wno-dev -G Ninja ..

ninja
ninja install
DESTDIR=$PWD/../../DEST ninja install

VERSION=${PWD%.src/*}
VERSION=${VERSION#*llvm-}
echo "$VERSION" > $PWD/../../VERSION
clang --version
ld.lld --version
