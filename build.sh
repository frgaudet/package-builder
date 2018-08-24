#!/bin/bash
# Ugly script with no real error management just used to build single linuxmint packages

base=trusty
arch=$1
package=$2

yell() { echo "$0: $*" >&2; }
die() { yell "$*"; exit 111; }
try() { "$@" || die "cannot $*"; }
asuser() { sudo su - "$1" -c "${*:2}"; }

try mkdir -p sandbox

if [ ! -d sandbox/$arch ]
then
  echo "Starting debootstrap"
  try debootstrap --arch $arch $base sandbox/$arch http://archive.ubuntu.com/ubuntu

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
try chroot sandbox/$arch apt-get update
try chroot sandbox/$arch apt-get install -y --force-yes dpkg-dev devscripts git-buildpackage debhelper libx11-dev libxtst-dev

echo "Importing Kubuntu key"
try chroot sandbox/$arch apt-key adv --recv-keys --keyserver keyserver.ubuntu.com 2836CB0A8AC93F7A

echo "Generating locale"
try chroot sandbox/$arch locale-gen en_US.UTF-8
try chroot sandbox/$arch locale-gen fr_FR.UTF-8

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
try mount -o bind /proc ./sandbox/$arch/proc/
try mount -o bind /dev ./sandbox/$arch/dev/


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
  DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true LANG=en_US.UTF-8 try chroot sandbox/$arch /bin/sh -c "cd sandbox/$package/$package;git-buildpackage -B"
else
  DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true LANG=en_US.UTF-8 try chroot sandbox/$arch /bin/sh -c "cd sandbox/$package/$package;git-buildpackage"
fi

#exit
try mount sandbox/$arch/proc/
try umount sandbox/$arch/dev/

mv sandbox/$arch/sandbox/$package/build-area/* packages/$package/build-area/
chown -R fred. packages/$package/build-area/*