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
# It also modified the GENTOO_PATCHSTAMP variable in the ebuild
# to have the same datestamp the tarball is named after.

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
EBUILD_BASE=$(basename ${EBUILD})
EBUILD_NAME=${EBUILD_BASE/-[0-9]*/}
TB_VER=${EBUILD_BASE/${EBUILD_NAME}-/}
TB_VER=${TB_VER/.ebuild/}
DATESTAMP=$(date +%Y%m%d)

case ${EBUILD_NAME} in
	apache)
		TREE=${TB_VER%.*}
		TB=gentoo-apache-${TB_VER}-${DATESTAMP}.tar.bz2
		TB_DIR=gentoo-apache-${TB_VER}
		UPDATE_EBUILD=1
		;;
	gentoo-webroot-default)
		TREE=gentoo-webroot-default
		TB=gentoo-webroot-default-${TB_VER}.tar.bz2
		TB_DIR=gentoo-webroot-default-${TB_VER}
		;;
	*)	
		die "Unknown ebuild";;
esac


# create tarball
echo "Creating ${TB} from ${TREE}/ ..."
cp -rl ${TREE} ${TB_DIR} || die "Copy failed"
date -u > ${TB_DIR}/DATESTAMP
echo "Packaged by ${G_USER}" >> ${TB_DIR}/DATESTAMP
tar --create --bzip2 --verbose --exclude=CVS --file ${TB} ${TB_DIR} || die "Tarball creation failed"
rm -rf ${TB_DIR} || echo "Couldn't clean up, manually remove ${TB_DIR}/"
echo " ... done!"
echo

# put it on the mirrors
echo "Putting ${TB} on the mirrors ..."
scp ${TB} ${G_USER}@dev.gentoo.org:/space/distfiles-local || die "Couldn't upload tarball"
echo " ... done!"
echo
echo "Please remember it can take up to 24 hours for full propogation"
echo "Make sure the tarball is on the mirrors before marking a package as stable"
echo
if [ "${UPDATE_EBUILD}" == "1" ]
then
	echo "Updating datestamp in ebuild ${EBUILD}"
	cp ${EBUILD} ${EBUILD}.bak
	sed "s/GENTOO_PATCHSTAMP=\"[0-9]*\"/GENTOO_PATCHSTAMP=\"${DATESTAMP}\"/" < ${EBUILD}.bak > ${EBUILD}
	echo
	echo "Please double check the change in the ebuild (should only effect the"
	echo "setting of GENTOO_PATCHSTAMP)"
	echo
fi
echo "Copy ${TB} to \${DISTFILES}, and run"
echo "ebuild \${EBUILD} digest."
echo
echo "Make sure to cvs up and echangelog before a repoman commit."
echo
echo "All finished!"
