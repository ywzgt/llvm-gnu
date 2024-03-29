#!/bin/bash

set -e
source envars.sh

VERSION=17.0.6
PKG="$PWD/DEST"
TRIPLE="$(gcc -dumpmachine)"
TRIPLE="${TRIPLE/x86_64/i386}"
RUNTIMES="libunwind;libcxx;libcxxabi"
URL="https://github.com/llvm/llvm-project/releases/download/llvmorg-${VERSION}"

SRC=(
	cmake
	compiler-rt
	libunwind
	llvm
	runtimes
	third-party
)

if [[ $1 = stdcxx ]]; then
	CXX=libstdc++
	RUNTIMES=libunwind
	shift
else
	SRC+=(libcxx{,abi})
fi

pre_src() {
	rm -rf bld_multi; mkdir bld_multi
	for f in ${SRC[@]}; do
		wget -q -c ${URL}/$f-${VERSION}.src.tar.xz
		tar xf $f-${VERSION}.src.tar.xz -C bld_multi
		ln -srv bld_multi/$f{-$VERSION.src,}
	done

	cd bld_multi
	patch -p1 -d libcxx/ <../libcxx-uClibc-no-catopen.patch
	install -Dm755 /dev/stdin ./${TRIPLE}-gcc <<-"EOF"
	#!/bin/sh
		exec gcc -m32 $@
	EOF

	install -Dm755 /dev/stdin ./${TRIPLE}-g++ <<-"EOF"
	#!/bin/sh
		exec g++ -m32 $@
	EOF

	ln -s /bin/clang ${TRIPLE}-clang
	ln -s /bin/clang++ ${TRIPLE}-clang++
# 	CFLAGS="${CFLAGS/x86-64-v?/i686}"
# 	CXXFLAGS="${CXXFLAGS/x86-64-v?/i686}"
}

rt_args=(
	-DCOMPILER_RT_BUILD_LIBFUZZER=OFF
	-DCOMPILER_RT_BUILD_MEMPROF=OFF
	-DCOMPILER_RT_BUILD_ORC=OFF
	-DCOMPILER_RT_BUILD_PROFILE=OFF
	-DCOMPILER_RT_BUILD_SANITIZERS=OFF
	-DCOMPILER_RT_BUILD_XRAY=OFF
)

stage1() {
	CC=${TRIPLE}-gcc CXX=${TRIPLE}-g++ \
	cmake -S runtimes -B build \
	-DCMAKE_INSTALL_PREFIX=/usr \
	-DCMAKE_BUILD_TYPE=Release -GNinja \
	-DLLVM_ENABLE_RUNTIMES="${RUNTIMES}"
	DESTDIR=$PWD/pkg ninja install -C build; cp -a pkg/usr/lib/* /usr/lib32/

	rm -rf build pkg
	CC=${TRIPLE}-gcc CXX=${TRIPLE}-g++ \
	cmake -S runtimes -B build \
	-DCMAKE_INSTALL_PREFIX=/usr \
	-DCMAKE_BUILD_TYPE=Release -GNinja \
	-DCAN_TARGET_i386=ON -DCAN_TARGET_x86_64=OFF \
	-DLLVM_ENABLE_RUNTIMES=compiler-rt "${rt_args[@]}"
	DESTDIR=$PWD/pkg ninja install -C build
	for i in pkg/usr/lib/linux/*-i386.*; do
		f=${i##*/}
		install -Dvm644 $i "${rt_install_dir}/${f/-i386}"
	done
}

stage2() {
	[ $# -eq 0 ] || printf "$* \n"

	rm -rf build pkg "$PKG"
	cmake -S runtimes -B build \
	-DCMAKE_INSTALL_PREFIX=/usr \
	-DCMAKE_BUILD_TYPE=Release -GNinja \
	-DLLVM_ENABLE_RUNTIMES="${RUNTIMES}" \
	-DLIBCXX_ENABLE_WIDE_CHARACTERS=OFF \
	-DLIBCXX_HAS_ATOMIC_LIB=OFF $*
	DESTDIR=$PKG ninja install -C build
	ninja install -C build
	cat > /usr/lib/clang/clang.cfg <<-EOF
	# It is used to control the default runtimes using by clang.

	--rtlib=compiler-rt
	--unwindlib=libunwind
	--stdlib=libc++
	-fstack-protector-strong
	EOF
	return
	mkdir -p "$PKG/usr/lib32"
	cp -a pkg/usr/lib/* /usr/lib32/
	cp -a pkg/usr/lib/* "$PKG/usr/lib32/"

	if [[ -f ${rt_install_dir}/libclang_rt.asan.so && $# -gt 0 ]]; then
		echo "::The 32-bit compiler-rt built-in library and sanitizers already exists! "
		echo "::SKIP build compiler-rt."
		return
	else
		rm -rf "${PKG}${rt_install_dir}"
	fi

	rm -rf build pkg
	CC=clang CXX=clang++ \
	CFLAGS="${CFLAGS} -m32" \
	CXXFLAGS="${CXXFLAGS} -m32" \
	cmake -S runtimes -B build \
	-DCMAKE_INSTALL_PREFIX=/usr \
	-DCMAKE_BUILD_TYPE=Release -GNinja \
	-DCAN_TARGET_i386=ON -DCAN_TARGET_x86_64=OFF \
	-DLLVM_ENABLE_RUNTIMES=compiler-rt \
	-DCOMPILER_RT_INCLUDE_TESTS=OFF \
	-DCOMPILER_RT_USE_BUILTINS_LIBRARY=ON \
	-DLLVM_DEFAULT_TARGET_TRIPLE=$(gcc -dumpmachine) \
	$([[ $CXX ]] || echo -DSANITIZER_CXX_ABI=libcxxabi) "${rt_args[@]}"
	DESTDIR=$PWD/pkg ninja install -C build
	for i in pkg/usr/lib/linux/*-i386.*; do
		f=${i##*/}
		install -Dvm644 $i "${rt_install_dir}/${f/-i386}"
	done
	if [ $# -gt 0 ]; then
		chmod 755 ${rt_install_dir}/*.so || true
		mkdir -p ${PKG}${rt_install_dir%/i386-*}
		cp -a ${rt_install_dir} "${PKG}${rt_install_dir%/i386-*}"
	fi
}

echo 'int main(){}' > main.c
if ! gcc -m32 main.c 2> /dev/null; then
	echo "::Error: Compiler does not support -m32"
	exit 1
else
	rm -f main.c a.out
fi

pre_src
rt_install_dir="/usr/lib/clang/${VERSION%%.*}/lib/${TRIPLE}"

if [[ $1 != pre ]]; then
	stage2 "::PASS1\n"
	stage2 "::PASS2\n"
else
	stage2; stage2 -DLIB{UNWIND,CXX{,ABI}}_USE_COMPILER_RT=ON \
	-DCMAKE_C_COMPILER=clang \
	-DCMAKE_CXX_COMPILER=clang++
fi
