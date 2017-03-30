#

set -e

: ${LFS:?} ${LFS_TGT:?}

#
# ============================================================================ #
# Download tools
#

SOURCES_DIR="$LFS/sources"

echo "Download tools' sources"

mkdir -p "$SOURCES_DIR"
pushd "$SOURCES_DIR"

wget -nv -nc http://www.linuxfromscratch.org/lfs/view/stable/wget-list
wget -nv -nc --input-file=wget-list --continue

wget -nv -nc http://www.linuxfromscratch.org/lfs/view/stable/md5sums
md5sum --quiet -c md5sums

popd

echo "Ok"

#
# ============================================================================ #
# Build tools
#

mkdir -p "$LFS/tools"
ln -s "$LFS/tools" /

su - lfs

cd "$LFS/sources"
: ${LFS:?} ${LFS_TGT:?}

function package
{
	TMP_DIR="/tmp/ft_linux_build"
	set -e
	cd "$LFS/sources"
	rm -rf "$TMP_DIR"
	mkdir -p "$TMP_DIR"
	echo "Installing $1"
	tar xf "$1" -C "$TMP_DIR"
	cd "$TMP_DIR"
	LS=$(ls)
	if [ "$(echo "$LS" | wc -l)" -eq 1 ]
	then cd "$LS"; fi
}

# 1 SBU ~ 2 min 09
time \
( package "binutils-2.27.tar.bz2"
	mkdir build; cd build
	../configure --prefix=/tools	\
		--with-sysroot="$LFS"		\
		--with-lib-path=/tools/lib	\
		--target="$LFS_TGT"			\
		--disable-nls				\
		--disable-werror
	make
	case $(uname -m) in
		x86_64) mkdir -p /tools/lib && ln -sv lib /tools/lib64 ;;
	esac
	make install
)

( package "gcc-6.3.0.tar.bz2"
	tar xf "$LFS"/sources/mpfr-3.1.5.tar.xz && mv mpfr-3.1.5 mpfr
	tar xf "$LFS"/sources/gmp-6.1.2.tar.xz && mv gmp-6.1.2 gmp
	tar xf "$LFS"/sources/mpc-1.0.3.tar.gz && mv mpc-1.0.3 mpc
	for file in gcc/config/{linux,i386/linux{,64}}.h
	do
		cp -uv $file{,.orig}
		sed -e 's@/lib\(64\)\?\(32\)\?/ld@/tools&@g' \
			-e 's@/usr@/tools@g' $file.orig > $file
		echo '
#undef STANDARD_STARTFILE_PREFIX_1
#undef STANDARD_STARTFILE_PREFIX_2
#define STANDARD_STARTFILE_PREFIX_1 "/tools/lib/"
#define STANDARD_STARTFILE_PREFIX_2 ""' >> $file
		touch $file.orig
	done
	case $(uname -m) in
		x86_64) sed -e '/m64=/s/lib64/lib/' -i.orig gcc/config/i386/t-linux64 ;;
	esac
	mkdir build; cd build
	../configure										\
		--target="$LFS_TGT"								\
		--prefix=/tools									\
		--with-glibc-version=2.11						\
		--with-sysroot="$LFS"							\
		--with-newlib									\
		--without-headers								\
		--with-local-prefix=/tools						\
		--with-native-system-header-dir=/tools/include	\
		--disable-nls									\
		--disable-shared								\
		--disable-multilib								\
		--disable-decimal-float							\
		--disable-threads								\
		--disable-libatomic								\
		--disable-libgomp								\
		--disable-libmpx								\
		--disable-libquadmath							\
		--disable-libssp								\
		--disable-libvtv								\
		--disable-libstdcxx								\
		--enable-languages=c,c++
	make
	make install
)

( package "linux-4.9.9.tar.xz"
	make mrproper
	make INSTALL_HDR_PATH=dest headers_install
	cp -r dest/include/* /tools/include
)

( package "glibc-2.25.tar.xz"
	mkdir build; cd build
	../configure							\
		--prefix=/tools						\
		--host=$LFS_TGT						\
		--build=$(../scripts/config.guess)	\
		--enable-kernel=2.6.32				\
		--with-headers=/tools/include		\
		libc_cv_forced_unwind=yes			\
		libc_cv_c_cleanup=yes
	make
	make install
)

( package "gcc-6.3.0.tar.bz2"
	mkdir build; cd build
	../libstdc++-v3/configure				\
		--host="$LFS_TGT"					\
		--prefix=/tools						\
		--disable-multilib					\
		--disable-nls						\
		--disable-libstdcxx-threads			\
		--disable-libstdcxx-pch				\
		--with-gxx-include-dir=/tools/"$LFS_TGT"/include/c++/6.3.0
	make -j2
	make install
)

( package "binutils-2.27.tar.bz2"
	mkdir build; cd build
	CC=$LFS_TGT-gcc					\
	AR=$LFS_TGT-ar					\
	RANLIB=$LFS_TGT-ranlib			\
	../configure					\
		--prefix=/tools				\
		--disable-nls				\
		--disable-werror			\
		--with-lib-path=/tools/lib	\
		--with-sysroot
	make -j2
	make install
	make -C ld clean
	make -C ld LIB_PATH=/usr/lib:/lib
	cp ld/ld-new /tools/bin
)

( package "gcc-6.3.0.tar.bz2"
	cat gcc/limitx.h gcc/glimits.h gcc/limity.h > \
		`dirname $($LFS_TGT-gcc -print-libgcc-file-name)`/include-fixed/limits.h
	for file in gcc/config/{linux,i386/linux{,64}}.h
	do
		cp -uv $file{,.orig}
		sed -e 's@/lib\(64\)\?\(32\)\?/ld@/tools&@g' \
			-e 's@/usr@/tools@g' $file.orig > $file
		echo '
#undef STANDARD_STARTFILE_PREFIX_1
#undef STANDARD_STARTFILE_PREFIX_2
#define STANDARD_STARTFILE_PREFIX_1 "/tools/lib/"
#define STANDARD_STARTFILE_PREFIX_2 ""' >> $file
		touch $file.orig
	done
	case $(uname -m) in
		x86_64) sed -e '/m64=/s/lib64/lib/' -i.orig gcc/config/i386/t-linux64 ;;
	esac
	tar xf "$LFS"/sources/mpfr-3.1.5.tar.xz && mv mpfr-3.1.5 mpfr
	tar xf "$LFS"/sources/gmp-6.1.2.tar.xz && mv gmp-6.1.2 gmp
	tar xf "$LFS"/sources/mpc-1.0.3.tar.gz && mv mpc-1.0.3 mpc
	mkdir build; cd build
	CC=$LFS_TGT-gcc							\
	CXX=$LFS_TGT-g++						\
	AR=$LFS_TGT-ar							\
	RANLIB=$LFS_TGT-ranlib					\
	../configure										\
		--prefix=/tools									\
		--with-local-prefix=/tools						\
		--with-native-system-header-dir=/tools/include	\
		--enable-languages=c,c++						\
		--disable-libstdcxx-pch							\
		--disable-multilib								\
		--disable-bootstrap								\
		--disable-libgomp
	make -j4
	make install
	ln -s gcc /tools/bin/cc
)

( package "tcl-core8.6.6-src.tar.gz"
	cd unix
	./configure --prefix=/tools
	make
	# TZ=UTC make test || true
	make install
	chmod -v u+w /tools/lib/libtcl8.6.so
	make install-private-headers
	ln -s tclsh8.6 /tools/bin/tclsh
)

( package "expect5.45.tar.gz"
	cp -v configure{,.orig}
	sed 's:/usr/local/bin:/bin:' configure.orig > configure
	./configure --prefix=/tools				\
		--with-tcl=/tools/lib				\
		--with-tclinclude=/tools/include
	make -j4
	make SCRIPTS="" install
)

( package "dejagnu-1.6.tar.gz"; ./configure --prefix=/tools; make install; make check )
( package "check-0.11.0.tar.gz"; PKG_CONFIG= ./configure --prefix=/tools; make -j4; make install )

( package "ncurses-6.0.tar.gz"
	sed -i s/mawk// configure
	./configure --prefix=/tools	\
		--with-shared			\
		--without-debug			\
		--without-ada			\
		--enable-widec			\
		--enable-overwrite
	make -j4
	make install
)

( package "bash-4.4.tar.gz"
	./configure --prefix=/tools --without-bash-malloc
	make -j4
	make install
	ln -s bash /tools/bin/sh
)

( package "bison-3.0.4.tar.xz"; ./configure --prefix=/tools; make -j4; make install )
( package "bzip2-1.0.6.tar.gz"; make; make PREFIX=/tools install )
( package "coreutils-8.26.tar.xz"; ./configure --prefix=/tools --enable-install-program=hostname; make -j4; make install )
( package "diffutils-3.5.tar.xz"; ./configure --prefix=/tools; make; make install )
( package "file-5.30.tar.gz"; ./configure --prefix=/tools; make -j4; make install )
( package "findutils-4.6.0.tar.gz"; ./configure --prefix=/tools; make -j4; make install )
( package "gawk-4.1.4.tar.xz"; ./configure --prefix=/tools; make -j4; make install )

( package "gettext-0.19.8.1.tar.xz"
	cd gettext-tools
	EMACS="no" ./configure --prefix=/tools --disable-shared
	make -j4 -C gnulib-lib
	make -j4 -C intl pluralx.c
	make -j4 -C src msgfmt
	make -j4 -C src msgmerge
	make -j4 -C src xgettext
	cp src/{msgfmt,msgmerge,xgettext} /tools/bin
)

( package "grep-3.0.tar.xz"; ./configure --prefix=/tools; make -j4; make install )
( package "gzip-1.8.tar.xz"; ./configure --prefix=/tools; make -j4; make install )
( package "m4-1.4.18.tar.xz"; ./configure --prefix=/tools; make -j4; make install )
( package "make-4.2.1.tar.bz2"; ./configure --prefix=/tools --without-guile; make -j4; make install )
( package "patch-2.7.5.tar.xz"; ./configure --prefix=/tools; make -j4; make install )

( package "perl-5.24.1.tar.bz2"
	sh Configure -des -Dprefix=/tools -Dlibs=-lm
	make -j4
	cp perl cpan/podlators/scripts/pod2man /tools/bin
	mkdir -p /tools/lib/perl5/5.24.1
	cp -R lib/* /tools/lib/perl5/5.24.1
)

( package "sed-4.4.tar.xz"; ./configure --prefix=/tools; make -j4; make install )
( package "tar-1.29.tar.xz"; ./configure --prefix=/tools; make -j4; make install )
( package "texinfo-6.3.tar.xz"; ./configure --prefix=/tools; make -j4; make install )

( package "util-linux-2.29.1.tar.xz"
	./configure --prefix=/tools			\
		--without-python				\
		--disable-makeinstall-chown		\
		--without-systemdsystemunitdir	\
		PKG_CONFIG=""
	make -j4
	make install
)

( package "xz-5.2.3.tar.xz"; ./configure --prefix=/tools; make -j4; make install )

#
# Strip
#

strip --strip-debug /tools/lib/* || true
/usr/bin/strip --strip-unneeded /tools/{,s}bin/* || true
rm -rf /tools/{,share}/{info,man,doc}

exit

#
# ============================================================================ #
#

chown -R root:root $LFS/tools
