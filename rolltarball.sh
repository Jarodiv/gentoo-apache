#!/bin/bash
# Copyright 2005 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header$

# This utility rolls a tarball.
# It takes a single argument:
#	the path to the ebuild the tarball is for.
# A second optional argument is the gentoo username
# It autodetects what the name of the tarball should be,
# creates the tarball, and drops it on 
# /space/distfiles-local on dev.gentoo.org
# (It get's your username from CVS information)

EBUILD=$1
G_USER=$2

die() {
	echo $@
	exit 1
}


if [ -z "${EBUILD}" ]
then
	die "You must specify the ebuild this tarball is for!"
fi


# detect username
if [ "x${G_USER}" == "x" ]
then
	G_USER=$(cat CVS/Root)
	G_USER=${G_USER/:ext:/}
	G_USER=${G_USER%@*}
fi
echo "Gentoo developer: ${G_USER}"
echo

# Check for updates
echo "Updating the tree and checking for program updates ..."
my_mtime=$(stat --format=%Y $0)
cvs up || die "cvs up failed!"
new_mtime=$(stat --format=%Y $0)
echo " ... done!"
echo

if [ "${my_mtime}" -ne "${new_mtime}" ]
then
	die "I have been updated, please restart me!"
fi


# detect the tarball name
EBUILD=$(basename ${EBUILD})
EBUILD_NAME=${EBUILD/-[0-9]*/}
TB_VER=${EBUILD/${EBUILD_NAME}-/}
TB_VER=${TB_VER/.ebuild/}

case ${EBUILD_NAME} in
	apache)
		TB_NAME=gentoo-apache
		TREE=${TB_VER%.*}
		;;
	gentoo-webroot-default)
		TB_NAME=gentoo-webroot-default
		TREE=gentoo-webroot-default
		;;
	*)	
		die "Unknown ebuild";;
esac


# create tarball
TB=${TB_NAME}-${TB_VER}
echo "Creating ${TB}.tar.bz2 from ${TREE}/ ..."
cp -rl ${TREE} ${TB} || die "Copy failed"
date -u > ${TB}/DATESTAMP
echo "Packaged by ${G_USER}" >> ${TB}/DATESTAMP
tar --create --bzip2 --verbose --exclude=CVS --file ${TB}.tar.bz2 ${TB} || die "Tarball creation failed"
rm -rf ${TB} || echo "Couldn't clean up, manually remove ${TB}/"
echo " ... done!"
echo

# put it on the mirrors
echo "Putting ${TB}.tar.bz2 on the mirrors ..."
scp ${TB}.tar.bz2 ${G_USER}@dev.gentoo.org:/space/distfiles-local || die "Couldn't upload tarball"
echo " ... done!"
echo
echo "Please remember it can take up to 24 hours for full propogation"
echo "Make sure the tarball is on the mirrors before marking a package as stable"
echo
echo "All finished!"

