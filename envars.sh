case $(uname -m) in
	i?86)
		CFLAGS="-march=i686"
		;;
	x86_64)
		CFLAGS="-march=x86-64-v3"
		;;
esac

export CFLAGS="$CFLAGS -mtune=haswell -O2 -pipe -fno-plt -fPIC"
export CXXFLAGS="$CFLAGS -Wp,-D_GLIBCXX_ASSERTIONS"
export CPPFLAGS="-DNDEBUG"
export LDFLAGS="-Wl,-O2,--sort-common,--as-needed,-z,relro,-z,now"
export MAKEFLAGS="-j$(nproc)"
export NINJAJOBS="$(nproc)"
export NINJA_STATUS="[%r %f/%t %es] "
