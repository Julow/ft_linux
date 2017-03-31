#

set -e

: ${LFS:?} ${LFS_TGT:?}

#
# ============================================================================ #
# ============================================================================ #
# Tools
# ============================================================================ #
# ============================================================================ #
#

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
# ============================================================================ #
# LFS
# ============================================================================ #
# ============================================================================ #
#

#
# ============================================================================ #
# Setup virtual kernel file systems
#

chown -R root:root $LFS/tools

mkdir -pv $LFS/{dev,proc,sys,run}
mknod -m 600 $LFS/dev/console c 5 1
mknod -m 666 $LFS/dev/null c 1 3
mount -v --bind /dev $LFS/dev
mount -vt devpts devpts $LFS/dev/pts -o gid=5,mode=620
mount -vt proc proc $LFS/proc
mount -vt sysfs sysfs $LFS/sys
mount -vt tmpfs tmpfs $LFS/run
if [ -h $LFS/dev/shm ]; then mkdir -pv $LFS/$(readlink $LFS/dev/shm); fi

chroot "$LFS" /tools/bin/env -i						\
	HOME=/root										\
	TERM="$TERM"									\
	PS1='\u:\w\$ '									\
	PATH=/bin:/usr/bin:/sbin:/usr/sbin:/tools/bin	\
	/tools/bin/bash --login +h

set -e

#
# ============================================================================ #
# Install basic files
#

mkdir -pv /{bin,boot,etc/{opt,sysconfig},home,lib/firmware,mnt,opt}
mkdir -pv /{media/{floppy,cdrom},sbin,srv,var}

install -dv -m 0750 /root
install -dv -m 1777 /tmp /var/tmp

mkdir -pv /usr/{,local/}{bin,include,lib,sbin,src}
mkdir -pv /usr/{,local/}share/{color,dict,doc,info,locale,man}
mkdir -v  /usr/{,local/}share/{misc,terminfo,zoneinfo}
mkdir -v  /usr/libexec
mkdir -pv /usr/{,local/}share/man/man{1..8}

case $(uname -m) in
	x86_64) mkdir -v /lib64 ;;
esac

mkdir -v /var/{log,mail,spool}
ln -sv /run /var/run
ln -sv /run/lock /var/lock
mkdir -pv /var/{opt,cache,lib/{color,misc,locate},local}

#
ln -sv /tools/bin/{bash,cat,echo,pwd,stty} /bin
ln -sv /tools/bin/perl /usr/bin
ln -sv /tools/lib/libgcc_s.so{,.1} /usr/lib
ln -sv /tools/lib/libstdc++.so{,.6} /usr/lib
sed 's/tools/usr/' /tools/lib/libstdc++.la > /usr/lib/libstdc++.la
ln -sv bash /bin/sh

ln -sv /proc/self/mounts /etc/mtab

cat > /etc/passwd << "EOF"
root:x:0:0:root:/root:/bin/bash
bin:x:1:1:bin:/dev/null:/bin/false
daemon:x:6:6:Daemon User:/dev/null:/bin/false
messagebus:x:18:18:D-Bus Message Daemon User:/var/run/dbus:/bin/false
nobody:x:99:99:Unprivileged User:/dev/null:/bin/false
EOF

cat > /etc/group << "EOF"
root:x:0:
bin:x:1:daemon
sys:x:2:
kmem:x:3:
tape:x:4:
tty:x:5:
daemon:x:6:
floppy:x:7:
disk:x:8:
lp:x:9:
dialout:x:10:
audio:x:11:
video:x:12:
utmp:x:13:
usb:x:14:
cdrom:x:15:
adm:x:16:
messagebus:x:18:
systemd-journal:x:23:
input:x:24:
mail:x:34:
nogroup:x:99:
users:x:999:
EOF

exec /tools/bin/bash --login +h

touch /var/log/{btmp,lastlog,faillog,wtmp}
chgrp -v utmp /var/log/lastlog
chmod -v 664  /var/log/lastlog
chmod -v 600  /var/log/btmp

#
# ============================================================================ #
# Install packages
#

function package
{
	TMP_DIR="/tmp/ft_linux_build"
	set -e
	cd "/sources"
	rm -rf "$TMP_DIR"
	mkdir -p "$TMP_DIR"
	echo "Installing $1"
	tar xf "$1" -C "$TMP_DIR"
	cd "$TMP_DIR"
	LS=$(ls)
	if [ "$(echo "$LS" | wc -l)" -eq 1 ]
	then cd "$LS"; fi
}

( package "linux-4.9.9.tar.xz"
	make mrproper
	make INSTALL_HDR_PATH=dest headers_install
	find dest/include \( -name .install -o -name ..install.cmd \) -delete
	cp -rv dest/include/* /usr/include
)

( package "man-pages-4.09.tar.xz"; make install )

( package "glibc-2.25.tar.xz"
	patch -Np1 -i /sources/glibc-2.25-fhs-1.patch
	case $(uname -m) in
		x86) ln -sf ld-linux.so.2 /lib/ld-lsb.so.3 ;;
		x86_64)
			ln -sf ../lib/ld-linux-x86-64.so.2 /lib64
			ln -sf ../lib/ld-linux-x86-64.so.2 /lib64/ld-lsb-x86-64.so.3
			;;
	esac
	mkdir build; cd build
	../configure --prefix=/usr			\
		--enable-kernel=2.6.32			\
		--enable-obsolete-rpc			\
		--enable-stack-protector=strong	\
		libc_cv_slibdir=/lib
	make
	touch /etc/ld.so.conf
	make install
	cp -v ../nscd/nscd.conf /etc/nscd.conf
	mkdir -pv /var/cache/nscd
	mkdir -pv /usr/lib/locale
	localedef -i cs_CZ -f UTF-8 cs_CZ.UTF-8
	localedef -i de_DE -f ISO-8859-1 de_DE
	localedef -i de_DE@euro -f ISO-8859-15 de_DE@euro
	localedef -i de_DE -f UTF-8 de_DE.UTF-8
	localedef -i en_GB -f UTF-8 en_GB.UTF-8
	localedef -i en_HK -f ISO-8859-1 en_HK
	localedef -i en_PH -f ISO-8859-1 en_PH
	localedef -i en_US -f ISO-8859-1 en_US
	localedef -i en_US -f UTF-8 en_US.UTF-8
	localedef -i es_MX -f ISO-8859-1 es_MX
	localedef -i fa_IR -f UTF-8 fa_IR
	localedef -i fr_FR -f ISO-8859-1 fr_FR
	localedef -i fr_FR@euro -f ISO-8859-15 fr_FR@euro
	localedef -i fr_FR -f UTF-8 fr_FR.UTF-8
	localedef -i it_IT -f ISO-8859-1 it_IT
	localedef -i it_IT -f UTF-8 it_IT.UTF-8
	localedef -i ja_JP -f EUC-JP ja_JP
	localedef -i ru_RU -f KOI8-R ru_RU.KOI8-R
	localedef -i ru_RU -f UTF-8 ru_RU.UTF-8
	localedef -i tr_TR -f UTF-8 tr_TR.UTF-8
	localedef -i zh_CN -f GB18030 zh_CN.GB18030
	make localedata/install-locales

	cat > /etc/nsswitch.conf << "EOF"
# Begin /etc/nsswitch.conf

passwd: files
group: files
shadow: files

hosts: files dns
networks: files

protocols: files
services: files
ethers: files
rpc: files

# End /etc/nsswitch.conf
EOF
	tar -xf /sources/tzdata2016j.tar.gz
	ZONEINFO=/usr/share/zoneinfo
	mkdir -pv $ZONEINFO/{posix,right}
	for tz in etcetera southamerica northamerica europe africa antarctica  \
			asia australasia backward pacificnew systemv; do
		zic -L /dev/null   -d $ZONEINFO       -y "sh yearistype.sh" ${tz}
		zic -L /dev/null   -d $ZONEINFO/posix -y "sh yearistype.sh" ${tz}
		zic -L leapseconds -d $ZONEINFO/right -y "sh yearistype.sh" ${tz}
	done
	cp -v zone.tab zone1970.tab iso3166.tab $ZONEINFO
	zic -d $ZONEINFO -p America/New_York
	unset ZONEINFO
	cat > /etc/ld.so.conf << "EOF"
# Begin /etc/ld.so.conf
/usr/local/lib
/opt/lib

EOF
	cat >> /etc/ld.so.conf << "EOF"
# Add an include directory
include /etc/ld.so.conf.d/*.conf

EOF
	mkdir -pv /etc/ld.so.conf.d
)

# ! interactive
cp -v /usr/share/zoneinfo/"`tzselect`" /etc/localtime

mv -v /tools/bin/{ld,ld-old}
mv -v /tools/$(uname -m)-pc-linux-gnu/bin/{ld,ld-old}
mv -v /tools/bin/{ld-new,ld}
ln -sv /tools/bin/ld /tools/$(uname -m)-pc-linux-gnu/bin/ld

gcc -dumpspecs | sed -e 's@/tools@@g'					\
	-e '/\*startfile_prefix_spec:/{n;s@.*@/usr/lib/ @}'	\
	-e '/\*cpp:/{n;s@$@ -isystem /usr/include@}' >		\
	`dirname $(gcc --print-libgcc-file-name)`/specs

( package "zlib-1.2.11.tar.xz"
	./configure --prefix=/usr
	make
	make install
	mv -v /usr/lib/libz.so.* /lib
	ln -sfv ../../lib/$(readlink /usr/lib/libz.so) /usr/lib/libz.so
)

( package "file-5.30.tar.gz"; ./configure --prefix=/usr; make; make install )

( package "binutils-2.27.tar.bz2"
	expect -c "spawn ls"
	mkdir build; cd build
	../configure --prefix=/usr	\
		--enable-gold			\
		--enable-ld=default		\
		--enable-plugins		\
		--enable-shared			\
		--disable-werror		\
		--with-system-zlib
	make tooldir=/usr
	make tooldir=/usr install
)

( package "gmp-6.1.2.tar.xz"
	./configure --prefix=/usr	\
		--enable-cxx			\
		--disable-static		\
		--docdir=/usr/share/doc/gmp-6.1.2
	make
	make check 2>&1 | tee gmp-check-log
	awk '/# PASS:/{total+=$3} ; END{print total}' gmp-check-log
	make install
)

( package "mpfr-3.1.5.tar.xz"
	./configure --prefix=/usr		\
		--disable-static			\
		--enable-thread-safe		\
		--docdir=/usr/share/doc/mpfr-3.1.5
	make
	make check
	make install
)

( package "mpc-1.0.3.tar.gz"
	./configure --prefix=/usr		\
		--disable-static			\
		--docdir=/usr/share/doc/mpc-1.0.3
	make
	make install
)

( package "gcc-6.3.0.tar.bz2"
	case $(uname -m) in
		x86_64) sed -e '/m64=/s/lib64/lib/' -i.orig gcc/config/i386/t-linux64 ;;
	esac
	mkdir build; cd build
	SED=sed							\
	../configure --prefix=/usr		\
		--enable-languages=c,c++	\
		--disable-multilib			\
		--disable-bootstrap			\
		--with-system-zlib
	make
	make install
	ln -sv ../usr/bin/cpp /lib
	ln -sv gcc /usr/bin/cc
	install -v -dm755 /usr/lib/bfd-plugins
	ln -sfv ../../libexec/gcc/$(gcc -dumpmachine)/6.3.0/liblto_plugin.so \
		/usr/lib/bfd-plugins/
	mkdir -pv /usr/share/gdb/auto-load/usr/lib
	mv -v /usr/lib/*gdb.py /usr/share/gdb/auto-load/usr/lib
)

( package "bzip2-1.0.6.tar.gz"
	patch -Np1 -i /sources/bzip2-1.0.6-install_docs-1.patch
	sed -i 's@\(ln -s -f \)$(PREFIX)/bin/@\1@' Makefile
	sed -i "s@(PREFIX)/man@(PREFIX)/share/man@g" Makefile
	make -f Makefile-libbz2_so
	make clean
	make
	make PREFIX=/usr install
	cp -v bzip2-shared /bin/bzip2
	cp -av libbz2.so* /lib
	ln -sv ../../lib/libbz2.so.1.0 /usr/lib/libbz2.so
	rm -v /usr/bin/{bunzip2,bzcat,bzip2}
	ln -sv bzip2 /bin/bunzip2
	ln -sv bzip2 /bin/bzcat
)

( package "pkg-config-0.29.1.tar.gz"
	./configure --prefix=/usr			\
		--with-internal-glib			\
		--disable-compile-warnings		\
		--disable-host-tool				\
		--docdir=/usr/share/doc/pkg-config-0.29.1
	make
	make install
)

( package "ncurses-6.0.tar.gz"
	sed -i '/LIBTOOL_INSTALL/d' c++/Makefile.in
	./configure --prefix=/usr		\
		--mandir=/usr/share/man		\
		--with-shared				\
		--without-debug				\
		--without-normal			\
		--enable-pc-files			\
		--enable-widec
	make
	make install
	mv -v /usr/lib/libncursesw.so.6* /lib
	ln -sfv ../../lib/$(readlink /usr/lib/libncursesw.so) /usr/lib/libncursesw.so
	for lib in ncurses form panel menu ; do
		rm -vf /usr/lib/lib${lib}.so
		echo "INPUT(-l${lib}w)" > /usr/lib/lib${lib}.so
		ln -sfv ${lib}w.pc /usr/lib/pkgconfig/${lib}.pc
	done
	rm -vf /usr/lib/libcursesw.so
	echo "INPUT(-lncursesw)" > /usr/lib/libcursesw.so
	ln -sfv libncurses.so /usr/lib/libcurses.so
	mkdir -v /usr/share/doc/ncurses-6.0
	cp -v -R doc/* /usr/share/doc/ncurses-6.0
)

( package "attr-2.4.47.src.tar.gz"
	sed -i -e 's|/@pkg_name@|&-@pkg_version@|' include/builddefs.in
	sed -i -e "/SUBDIRS/s|man[25]||g" man/Makefile
	./configure --prefix=/usr		\
		--bindir=/bin				\
		--disable-static
	make
	make install install-dev install-lib
	chmod -v 755 /usr/lib/libattr.so
	mv -v /usr/lib/libattr.so.* /lib
	ln -sfv ../../lib/$(readlink /usr/lib/libattr.so) /usr/lib/libattr.so
)

( package "acl-2.2.52.src.tar.gz"
	sed -i -e 's|/@pkg_name@|&-@pkg_version@|' include/builddefs.in
	sed -i "s:| sed.*::g" test/{sbits-restore,cp,misc}.test
	sed -i -e "/TABS-1;/a if (x > (TABS-1)) x = (TABS-1);" \
		libacl/__acl_to_any_text.c
	./configure --prefix=/usr		\
		--bindir=/bin				\
		--disable-static			\
		--libexecdir=/usr/lib
	make
	make install install-dev install-lib
	chmod -v 755 /usr/lib/libacl.so
	mv -v /usr/lib/libacl.so.* /lib
	ln -sfv ../../lib/$(readlink /usr/lib/libacl.so) /usr/lib/libacl.so
)

( package "libcap-2.25.tar.xz"
	sed -i '/install.*STALIBNAME/d' libcap/Makefile
	make
	make RAISE_SETFCAP=no lib=lib prefix=/usr install
	chmod -v 755 /usr/lib/libcap.so
	mv -v /usr/lib/libcap.so.* /lib
	ln -sfv ../../lib/$(readlink /usr/lib/libcap.so) /usr/lib/libcap.so
)

( package "sed-4.4.tar.xz"
	sed -i 's/usr/tools/' build-aux/help2man
	sed -i 's/panic-tests.sh//' Makefile.in
	./configure --prefix=/usr --bindir=/bin
	make
	make html
	make install
	install -d -m755 /usr/share/doc/sed-4.4
	install -m644 doc/sed.html /usr/share/doc/sed-4.4
)

( package "shadow-4.4.tar.xz"
	sed -i 's/groups$(EXEEXT) //' src/Makefile.in
	find man -name Makefile.in -exec sed -i 's/groups\.1 / /' {} \;
	find man -name Makefile.in -exec sed -i 's/getspnam\.3 / /' {} \;
	find man -name Makefile.in -exec sed -i 's/passwd\.5 / /' {} \;
	sed -i -e 's@#ENCRYPT_METHOD DES@ENCRYPT_METHOD SHA512@' \
		-e 's@/var/spool/mail@/var/mail@' etc/login.defs
	echo '--- src/useradd.c   (old)
+++ src/useradd.c   (new)
@@ -2027,6 +2027,8 @@
        is_shadow_grp = sgr_file_present ();
 #endif
 
+       get_defaults ();
+
        process_flags (argc, argv);
 
 #ifdef ENABLE_SUBIDS
@@ -2036,8 +2038,6 @@
            (!user_id || (user_id <= uid_max && user_id >= uid_min));
 #endif                         /* ENABLE_SUBIDS */
 
-       get_defaults ();
-
 #ifdef ACCT_TOOLS_SETUID
 #ifdef USE_PAM
        {' | patch -p0 -l
	sed -i 's/1000/999/' etc/useradd
	sed -i -e '47 d' -e '60,65 d' libmisc/myname.c
	./configure --sysconfdir=/etc --with-group-name-max-length=32
	make
	make install
	mv -v /usr/bin/passwd /bin
)

pwconv
grpconv
sed -i 's/yes/no/' /etc/default/useradd

# !interactive
passwd root

( package "psmisc-22.21.tar.gz"
	./configure --prefix=/usr
	make
	make install
	mv -v /usr/bin/fuser /bin
	mv -v /usr/bin/killall /bin
)

( package "iana-etc-2.30.tar.bz2"; make; make install )
( package "m4-1.4.18.tar.xz"; ./configure --prefix=/usr; make; make install )
( package "bison-3.0.4.tar.xz"; ./configure --prefix=/usr --docdir=/usr/share/doc/bison-3.0.4; make; make install )

( package "flex-2.6.3.tar.gz"
	HELP2MAN=/tools/bin/true \
	./configure --prefix=/usr --docdir=/usr/share/doc/flex-2.6.3
	make
	make install
	ln -sv flex /usr/bin/lex
)

( package "grep-3.0.tar.xz"; ./configure --prefix=/usr --bindir=/bin; make; make install )

( package "readline-7.0.tar.gz"
	sed -i '/MV.*old/d' Makefile.in
	sed -i '/{OLDSUFF}/c:' support/shlib-install
	./configure --prefix=/usr		\
		--disable-static			\
		--docdir=/usr/share/doc/readline-7.0
	make SHLIB_LIBS=-lncurses
	make SHLIB_LIBS=-lncurses install
	mv -v /usr/lib/lib{readline,history}.so.* /lib
	ln -sfv ../../lib/$(readlink /usr/lib/libreadline.so) /usr/lib/libreadline.so
	ln -sfv ../../lib/$(readlink /usr/lib/libhistory.so ) /usr/lib/libhistory.so
	install -v -m644 doc/*.{ps,pdf,html,dvi} /usr/share/doc/readline-7.0
)

( package "bash-4.4.tar.gz"
	patch -Np1 -i /sources/bash-4.4-upstream_fixes-1.patch
	./configure --prefix=/usr				\
		--docdir=/usr/share/doc/bash-4.4	\
		--without-bash-malloc				\
		--with-installed-readline
	make
	chown -Rv nobody .
	make install
	mv -vf /usr/bin/bash /bin
)

( package "bc-1.06.95.tar.bz2"
	patch -Np1 -i /sources/bc-1.06.95-memory_leak-1.patch
	./configure --prefix=/usr			\
		--with-readline					\
		--mandir=/usr/share/man			\
		--infodir=/usr/share/info
	make
	make install
)

( package "libtool-2.4.6.tar.xz"; ./configure --prefix=/usr; make; make install )

( package "gdbm-1.12.tar.gz"
	./configure --prefix=/usr --disable-static --enable-libgdbm-compat
	make
	make install
)

( package "gperf-3.0.4.tar.gz"
	./configure --prefix=/usr --docdir=/usr/share/doc/gperf-3.0.4
	make
	make install
)

( package "expat-2.2.0.tar.bz2"
	./configure --prefix=/usr --disable-static
	make
	make install
	install -v -dm755 /usr/share/doc/expat-2.2.0
	install -v -m644 doc/*.{html,png,css} /usr/share/doc/expat-2.2.0
)

( package "inetutils-1.9.4.tar.xz"
	./configure --prefix=/usr	\
		--localstatedir=/var	\
		--disable-logger		\
		--disable-whois			\
		--disable-rcp			\
		--disable-rexec			\
		--disable-rlogin		\
		--disable-rsh			\
		--disable-servers
	make
	make install
	mv -v /usr/bin/{hostname,ping,ping6,traceroute} /bin
	mv -v /usr/bin/ifconfig /sbin
)

( package "perl-5.24.1.tar.bz2"
	echo "127.0.0.1 localhost $(hostname)" > /etc/hosts
	export BUILD_ZLIB=False
	export BUILD_BZIP2=0
	sh Configure -des -Dprefix=/usr			\
		-Dvendorprefix=/usr					\
		-Dman1dir=/usr/share/man/man1		\
		-Dman3dir=/usr/share/man/man3		\
		-Dpager="/usr/bin/less -isR"		\
		-Duseshrplib
	make
	make install
	unset BUILD_ZLIB BUILD_BZIP2
)

( package "XML-Parser-2.44.tar.gz"; perl Makefile.PL; make; make install )

( package "intltool-0.51.0.tar.gz"
	sed -i 's:\\\${:\\\$\\{:' intltool-update.in
	./configure --prefix=/usr
	make
	make install
	install -v -Dm644 doc/I18N-HOWTO /usr/share/doc/intltool-0.51.0/I18N-HOWTO
)

( package "autoconf-2.69.tar.xz"; ./configure --prefix=/usr; make; make install )

( package "automake-1.15.tar.xz"
	sed -i 's:/\\\${:/\\\$\\{:' bin/automake.in
	./configure --prefix=/usr --docdir=/usr/share/doc/automake-1.15
	make
	make install
)

( package "xz-5.2.3.tar.xz"
	./configure --prefix=/usr		\
		--disable-static			\
		--docdir=/usr/share/doc/xz-5.2.3
	make
	make install
	mv -v /usr/bin/{lzma,unlzma,lzcat,xz,unxz,xzcat} /bin
	mv -v /usr/lib/liblzma.so.* /lib
	ln -svf ../../lib/$(readlink /usr/lib/liblzma.so) /usr/lib/liblzma.so
)

( package "kmod-23.tar.xz"
	./configure --prefix=/usr		\
		--bindir=/bin				\
		--sysconfdir=/etc			\
		--with-rootlibdir=/lib		\
		--with-xz					\
		--with-zlib
	make
	make install
	for target in depmod insmod lsmod modinfo modprobe rmmod; do
		ln -sfv ../bin/kmod /sbin/$target
	done
	ln -sfv kmod /bin/lsmod
)

( package "gettext-0.19.8.1.tar.xz"
	sed -i '/^TESTS =/d' gettext-runtime/tests/Makefile.in &&
	sed -i 's/test-lock..EXEEXT.//' gettext-tools/gnulib-tests/Makefile.in
	./configure --prefix=/usr		\
		--disable-static			\
		--docdir=/usr/share/doc/gettext-0.19.8.1
	make
	make install
	chmod -v 0755 /usr/lib/preloadable_libintl.so
)
