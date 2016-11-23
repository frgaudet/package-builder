#!/bin/bash
# Ugly script with no real error management just used to build single linuxmint packages

base=trusty
arch=$1
package=$2

mkdir -p sandbox

if [ ! -d sandbox/$arch ]
then
  echo "Starting debootstrap"
  debootstrap --arch $arch $base sandbox/$arch http://archive.ubuntu.com/ubuntu

  echo "Installing bashrc"

cat > sandbox/$arch/etc/bash.bashrc << EOF
export LANG=C
export LC_ALL=C
export LANGUAGE=C
EOF


echo "Install sources.list"
cat > sandbox/$arch/etc/apt/sources.list << EOF
deb-src http://packages.linuxmint.com olivia main import
deb http://archive.ubuntu.com/ubuntu/ $base main restricted universe multiverse
deb-src http://archive.ubuntu.com/ubuntu/ $base main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu/ $base-updates main restricted universe multiverse
deb-src http://archive.ubuntu.com/ubuntu/ $base-updates main restricted universe multiverse
deb http://security.ubuntu.com/ubuntu/ $base-security main restricted universe multiverse
deb-src http://security.ubuntu.com/ubuntu/ $base-security main restricted universe multiverse
deb http://archive.canonical.com/ubuntu/ $base partner
EOF

# Install buildpackages
echo "Install Buildpackges"
chroot sandbox/$arch apt-get update
chroot sandbox/$arch apt-get install -y --force-yes dpkg-dev devscripts git-buildpackage debhelper libx11-dev libxtst-dev

echo "Importing Kubuntu key"
chroot sandbox/$arch apt-key adv --recv-keys --keyserver keyserver.ubuntu.com 2836CB0A8AC93F7A

echo "Generating locale"
chroot sandbox/$arch locale-gen en_US.UTF-8
chroot sandbox/$arch locale-gen fr_FR.UTF-8

echo "Configure gbp"
cat > sandbox/$arch/etc/git-buildpackage/gbp.conf << EOF
# Configuration file for git-buildpackage and friends

[DEFAULT]
# the default build command:
builder = debuild -i -I -us -uc
# the default clean command:
cleaner = debuild clean
 
[git-buildpackage]
export-dir = ../build-area/
tarball-dir = ../tarballs/
EOF

fi

echo "Mounting ..."
mount -o bind /proc ./sandbox/$arch/proc/
mount -o bind /dev ./sandbox/$arch/dev/


# Install packages into sandbox
if [ ! -d sandbox/$arch/sandbox ]
then
  mkdir sandbox/$arch/sandbox
fi
rm packages/$package/build-area/*_$arch.*
rm -rf sandbox/$arch/sandbox/$package
cp -r packages/$package sandbox/$arch/sandbox/


# Update APT cache
echo "Update apt cache"
chroot sandbox/$arch apt-get update
chroot sandbox/$arch apt-get -y --forde-yes upgrade

# Build-dep
chroot sandbox/$arch apt-get build-dep -y --force-yes $package

echo "Selected arch=$arch"
echo "Selected package=$package"

# Build
if [ $arch == "i386" ]
then
  DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true LANG=en_US.UTF-8 chroot sandbox/$arch /bin/sh -c "cd sandbox/$package/$package;git-buildpackage -B"
else
  DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true LANG=en_US.UTF-8 chroot sandbox/$arch /bin/sh -c "cd sandbox/$package/$package;git-buildpackage"
fi

#exit
umount sandbox/$arch/proc/
umount sandbox/$arch/dev/

mv sandbox/$arch/sandbox/$package/build-area/* packages/$package/build-area/
chown -R fred. packages/$package/build-area/*