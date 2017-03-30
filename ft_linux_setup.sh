#

set -e

: ${LFS:?} ${LFS_TGT:?}

#
# ============================================================================ #
# lfs user
#

groupadd lfs
useradd -s /bin/bash -g lfs -m -k /dev/null lfs

passwd lfs << END
lfs
lfs
END

chown -v lfs $LFS/tools
chown -v lfs $LFS/sources

cat > /home/lfs/.bash_profile << "EOF"
exec env -i HOME=$HOME TERM=$TERM PS1='\u:\w\$ ' /bin/bash
EOF

cat > /home/lfs/.bashrc << EOF
set +h
umask 022
LFS=$LFS
LFS_TGT=$LFS_TGT
LC_ALL=POSIX
PATH=/tools/bin:/bin:/usr/bin
export LFS LFS_TGT LC_ALL PATH
EOF
