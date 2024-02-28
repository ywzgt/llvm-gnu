# curl -s https://linuxfromscratch.org/blfs/view/systemd/general/llvm.html | grep -o 'https://.*.\(xz\|patch\)' | uniq

set -e
source envars.sh

ELIBC=gnu
STDLIB=libcxx
VERSION=17.0.6

SRC=(
	https://github.com/llvm/llvm-project/releases/download/llvmorg-${VERSION}/llvm-${VERSION}.src.tar.xz
	https://github.com/llvm/llvm-project/releases/download/llvmorg-${VERSION}/cmake-${VERSION}.src.tar.xz
	https://github.com/llvm/llvm-project/releases/download/llvmorg-${VERSION}/third-party-${VERSION}.src.tar.xz

	https://www.linuxfromscratch.org/patches/blfs/svn/clang-17-enable_default_ssp-1.patch
	https://github.com/llvm/llvm-project/releases/download/llvmorg-${VERSION}/clang-${VERSION}.src.tar.xz
	https://github.com/llvm/llvm-project/releases/download/llvmorg-${VERSION}/compiler-rt-${VERSION}.src.tar.xz
	https://github.com/llvm/llvm-project/releases/download/llvmorg-${VERSION}/lld-${VERSION}.src.tar.xz
	https://github.com/llvm/llvm-project/releases/download/llvmorg-${VERSION}/libunwind-${VERSION}.src.tar.xz
)
# https://anduin.linuxfromscratch.org/BLFS/llvm/llvm-cmake-17.src.tar.xz
# https://anduin.linuxfromscratch.org/BLFS/llvm/llvm-third-party-17.src.tar.xz

# /build/llvm-17.0.6.src/tools/lld/MachO/Target.h:23:10: fatal error: mach-o/compact_unwind_encoding.h: No such file or directory
#    23 | #include "mach-o/compact_unwind_encoding.h"

for arg in $@; do
	case "$arg" in
		musl)
			ELIBC=musl
			;;
		nolibcxx)
			STDLIB=
			;;
	esac
done

if [[ $STDLIB = libcxx ]]; then
	SRC+=(
		https://github.com/llvm/llvm-project/releases/download/llvmorg-${VERSION}/libcxx-${VERSION}.src.tar.xz
		https://github.com/llvm/llvm-project/releases/download/llvmorg-${VERSION}/libcxxabi-${VERSION}.src.tar.xz
		https://github.com/llvm/llvm-project/releases/download/llvmorg-${VERSION}/runtimes-${VERSION}.src.tar.xz
	)
fi

rm -rf libunwind llvm-${VERSION}.src
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

cd llvm-${VERSION}.src
sed '/LLVM_COMMON_CMAKE_UTILS/s@../cmake@llvm-cmake-17.src@'          \
    -i CMakeLists.txt
sed '/LLVM_THIRD_PARTY_DIR/s@../third-party@llvm-third-party-17.src@' \
    -i cmake/modules/HandleLLVMOptions.cmake

while pidof -q tar; do sleep 0.1; done
mv ../cmake-${VERSION}.src llvm-cmake-17.src
mv ../third-party-${VERSION}.src llvm-third-party-17.src
mv ../clang-${VERSION}.src tools/clang
mv ../lld-${VERSION}.src tools/lld
mv ../libunwind-${VERSION}.src projects/libunwind
mv ../compiler-rt-${VERSION}.src projects/compiler-rt
sed '/^set(LLVM_COMMON_CMAKE_UTILS/d' -i projects/{compiler-rt,libunwind}/CMakeLists.txt
ln -sr projects/libunwind ..

if [[ $STDLIB = libcxx ]]; then
	mv ../libcxx-${VERSION}.src projects/libcxx
	mv ../libcxxabi-${VERSION}.src projects/libcxxabi
	cp -ri ../runtimes-${VERSION}.src/cmake/* llvm-cmake-17.src  # libc++abi testing configuration
	mv ../runtimes-${VERSION}.src llvm-runtimes-17.src
	sed -e '/^set(LLVM_COMMON_CMAKE_UTILS/s@../cmake@../llvm-cmake-17.src@' \
		-e '/LLVM_THIRD_PARTY_DIR/s@../third-party@../llvm-third-party-17.src@' \
		-e '/..\/llvm\(\/\|)\)/s/\/llvm//' -e '/${CMAKE_CURRENT_SOURCE_DIR}\/..\/${proj}/s/${proj}/projects\/&/' \
		-i llvm-runtimes-17.src/CMakeLists.txt
	sed '/CMAKE_CURRENT_SOURCE_DIR/s@../runtimes@llvm-runtimes-17.src@' \
		-i runtimes/CMakeLists.txt
	sed '/^set(LLVM_COMMON_CMAKE_UTILS/d' -i projects/libcxx{,abi}/CMakeLists.txt
	sed 's@../runtimes@llvm-runtimes-17.src@' -i \
		projects/compiler-rt/cmake/Modules/AddCompilerRT.cmake \
		projects/compiler-rt/lib/sanitizer_common/symbolizer/scripts/build_symbolizer.sh
	_args=(-DLIBCXX{,ABI}_INSTALL_LIBRARY_DIR=lib)
else
	for M in {HandleFlags,WarningFlags}.cmake; do
		if [ ! -e projects/libunwind/cmake/Modules/$M ]; then
			wget -nv -cP projects/libunwind/cmake/Modules \
				https://github.com/llvm/llvm-project/raw/llvmorg-${VERSION}/runtimes/cmake/Modules/$M
		fi
	done
fi

grep -rl '#!.*python' | xargs sed -i '1s/python$/python3/'

if [[ $ELIBC != musl ]]; then
	patch -Np2 -d tools/clang <../clang-17-enable_default_ssp-1.patch
	sed 's/clang_dfsan/& -fno-stack-protector/' \
		-i projects/compiler-rt/test/dfsan/origin_unaligned_memtrans.c
else
	_args+=(-DCOMPILER_RT_BUILD_GWP_ASAN=OFF)
	[ "$STDLIB" = libcxx ] && _args+=(-DLIBCXX_HAS_MUSL_LIBC=ON)
	if [[ $(gcc -dumpmachine) = i?86-*-musl ]]; then
		sed -i 's,^# Setup flags.$,add_library_flags(ssp_nonshared),' \
			projects/libunwind/src/CMakeLists.txt
		sed -i 's,^# Setup flags.$,add_library_flags(ssp_nonshared),' \
			projects/libcxxabi/src/CMakeLists.txt
		sed -i 's,#ssp,,' projects/libcxx/CMakeLists.txt
		_args+=(-DCOMPILER_RT_BUILD_SANITIZERS=OFF)
	fi
fi

mkdir -v build
cd build
echo

src_config() {
	if command -v clang{,++} > /dev/null; then
		CC=clang CXX=clang++ "$@" \
		-DCMAKE_SKIP_RPATH=ON
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
      -DLLVM_BUILD_TESTS=OFF \
      -DLLVM_INCLUDE_TESTS=OFF \
      -DLLVM_HOST_TRIPLE=$(gcc -dumpmachine) \
      -DCLANG_CONFIG_FILE_SYSTEM_DIR=/usr/lib/clang \
      -DLIBUNWIND_INSTALL_LIBRARY_DIR=/usr/lib \
      -Wno-dev -G Ninja "${_args[@]}" ..
# LIBUNWIND_INSTALL_LIBRARY_DIR 如果是相对路径可能会是相对于 当前目录，而不是 CMAKE_INSTALL_PREFIX

ninja
ninja install
rm -rf ../../DEST
DESTDIR=$PWD/../../DEST ninja install &> /dev/null

# https://packages.gentoo.org/packages/sys-devel/clang-common
cat > ../../DEST/usr/lib/clang/clang.cfg <<-EOF
	# It is used to control the default runtimes using by clang.

	--rtlib=compiler-rt
	--unwindlib=libunwind
	--stdlib=libc++
	-fuse-ld=lld
EOF

if [[ $STDLIB != libcxx ]]; then
	sed -i '/--stdlib=libc++$/d' ../../DEST/usr/lib/clang/clang.cfg
fi

ln -s clang.cfg "../../DEST/usr/lib/clang/clang++.cfg"
cp ../../DEST/usr/lib/clang/*.cfg "/usr/lib/clang/"

echo "$VERSION" > $PWD/../../VERSION
clang -v
echo
ld.lld --version
