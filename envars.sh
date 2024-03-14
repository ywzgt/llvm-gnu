case $(uname -m) in
	i?86)
		CFLAGS="-march=i686"
		;;
	x86_64)
		CFLAGS="-march=x86-64-v3"
		;;
esac

export CFLAGS="$CFLAGS -mtune=haswell -O2 -pipe -fno-plt -fPIC -ffunction-sections -fdata-sections"
export CXXFLAGS="$CFLAGS -Wp,-D_GLIBCXX_ASSERTIONS"
export CPPFLAGS="-D_FORTIFY_SOURCE=2 -DNDEBUG -D_LIBCPP_CXX03_LANG -UN__GLIBC__"
export LDFLAGS="-Wl,-O2,--sort-common,--as-needed,-z,relro,-z,now,--gc-sections"
export MAKEFLAGS="-j$(nproc)"
export NINJAJOBS="$(nproc)"
export NINJA_STATUS="[%r %f/%t %es] "
