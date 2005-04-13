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

# -------------------------------------------------------------
# import some functions and configs

. /sbin/functions.sh
. /etc/make.globals
. /etc/make.conf

die() {
	eerror $@
	exit 1
}

# void einfol(level, text...)
#
# print only when verbosity level equal or higher than $1
einfol() {
	if [ "${VERBOSE}" -ge "${1}" ]; then
		shift 1
		if [ $# -ne 0 ]; then
			einfo "${*}"
		else
			echo
		fi
	fi
}

# -------------------------------------------------------------
# configuration w/ default values

EBUILD=
G_USER=
VERBOSE=0 				# verbosity level
DRY_RUN= 				# does nothing (yet)
UPLOAD= 				# upload tarball?
DISTLOCAL= 				# copy tarball to DISTDIR
DIGEST= 				# -> and update digests

# -------------------------------------------------------------
# parse command-line arguments

usage_error() {
	if [ $# -ne 0 ]; then
		eerror "Usage error: ${*}"
		echo
	fi
	einfo "usage: $0 [--dry-run] [--verbose|-v] [--upload|-p]"
	einfo "           [--user=NAME|-u NAME] [--dist-local|-d]"
	einfo "           [--digest|-g] [--stfu]"
	einfo "           /path/to/apache-herd.ebuild"
	echo
	einfo "You may specify -v repeatily to increase verbosity."
	einfo "short arguments may be glued together (like -vv or -dgp)."
	exit 1
}

while test $# != 0; do
	case $1 in
		--*=*)
			opt_key=`expr "x$1" : 'x\([^=]*\)='`
			opt_val=`expr "x$1" : 'x[^=]*=\(.*\)'`
			opt_type=long
			;;
		-*)
			opt_key=$1
			opt_val=$2
			opt_type=short
			;;
		*)
			opt_key=
			opt_val=$1
			opt_type=raw
			;;
	esac

	einfol 3 "key($opt_key) value($opt_val)"

	if [ "${opt_key}" = "" ]; then
		# raw arguments are supposed to be ebuild location(s)
		EBUILD=${opt_val}
		shiftNum=1
	else
		shiftNum=1
		case ${opt_key} in
			--silent|--quiet|--stfu|--STFU) # yeah, STFU is what I like most ;-)
				VERBOSE=-1
				;;
			--verbose)
				VERBOSE=$[VERBOSE + 1]
				;;
			-v)
				VERBOSE=$[VERBOSE + 1]
				;;
			-vv)
				VERBOSE=$[VERBOSE + 2]
				;;
			-vvv)
				VERBOSE=$[VERBOSE + 3]
				;;
			--dry-run)
				DRY_RUN=1
				;;
			--user)
				G_USER=${opt_val}
				test "${opt_type}" = "short" && shiftNum=2
				;;
			-u)
				G_USER=${opt_val}
				shiftNum=2
				;;
			--upload|-p)
				UPLOAD=1
				;;
			--dist-local|-d)
				DISTLOCAL=1
				;;
			--digest)
				DIGEST=1
				;;
			-g)
				DIGEST=1
				;;
			-dg|-gd)
				DISTLOCAL=1
				DIGEST=1
				;;
			-dgp|-dpg|-gdp|-gpd|-pdg|-pgd)
				DISTLOCAL=1
				DIGEST=1
				UPLOAD=1
				;;
			*)
				usage_error "Unknown argument '${opt_key}'"
				;;
		esac
	fi
	shift ${shiftNum}
done

# -------------------------------------------------------------
# argument validation and post-handling

if [ "${VERBOSE}" -ge 2 ]; then
	exec 9>&1
else
	exec 9>/dev/null
fi

if [ -z "${EBUILD}" ]; then
	usage_error "No ebuild specified."
fi

if [ -z "${DISTLOCAL}" ] && [ -n "${DIGEST}" ]; then
	usage_error "digest can be only created when --dist-local is specified."
fi

# detect username
if [ "x${G_USER}" == "x" ]
then
	G_USER=$(cat CVS/Root)
	G_USER=${G_USER/:ext:/}
	G_USER=${G_USER%@*}
fi
einfol 1 "Gentoo developer: ${G_USER}"

# -------------------------------------------------------------
# Check for updates

einfol 1 "Updating the tree and checking for program updates ..."
my_mtime=$(stat --format=%Y $0)
cvs up >&9 || die "cvs up failed!"
new_mtime=$(stat --format=%Y $0)
einfol 2 "... done!"
einfol 2

if [ "${my_mtime}" -ne "${new_mtime}" ]
then
	die "I have been updated, please restart me!"
fi

# -------------------------------------------------------------
# detect the tarball name

EBUILD_BASE=$(basename ${EBUILD})
EBUILD_NAME=${EBUILD_BASE/-[0-9]*/}
TB_VER=${EBUILD_BASE/${EBUILD_NAME}-/}
TB_VER=${TB_VER/.ebuild/}
DATESTAMP=$(date +%Y%m%d)

einfol 2 "EBUILD_BASE : ${EBUILD_BASE}"
einfol 2 "EBUILD_NAME : ${EBUILD_NAME}"
einfol 2 "TB_VER      : ${TB_VER}"
einfol 2 "DATESTAMP   : ${DATESTAMP}"

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
		die "Unknown ebuild (ebuild name: ${EBUILD_NAME})";;
esac

# -------------------------------------------------------------
# create tarball

einfol 1 "Creating ${TB} from ${TREE}/ ..."
cp -rl ${TREE} ${TB_DIR} || die "Copy failed"
date -u > ${TB_DIR}/DATESTAMP
einfol 1 "Packaged by ${G_USER}" >> ${TB_DIR}/DATESTAMP
tar --create --bzip2 --verbose --exclude=CVS --file ${TB} ${TB_DIR} >&9 || die "Tarball creation failed"
rm -rf ${TB_DIR} || ewarn "Couldn't clean up, manually remove ${TB_DIR}/"
einfol 2 "... done!"
einfol 2

# -------------------------------------------------------------
if [ "${UPLOAD}" = "1" ]; then
	einfol 1 "Putting ${TB} on the mirrors ..."
	scp ${TB} ${G_USER}@dev.gentoo.org:/space/distfiles-local >&9 || die "Couldn't upload tarball"
	einfol 2 "... done!"
	einfol 1
	einfol 1 "Please remember it can take up to 24 hours for full propogation"
	einfol 1 "Make sure the tarball is on the mirrors before marking a package as stable"
	einfol 1
fi

# -------------------------------------------------------------
if [ "${UPDATE_EBUILD}" == "1" ]; then
	einfol 1 "Updating datestamp in ebuild ${EBUILD}"
	sed -i -e "s/GENTOO_PATCHSTAMP=\"[0-9]*\"/GENTOO_PATCHSTAMP=\"${DATESTAMP}\"/" ${EBUILD}
	einfol 1

	einfol 0 "Please double check the change in the ebuild (should only effect the"
	einfol 0 "setting of GENTOO_PATCHSTAMP)"
	einfol 0
fi

# -------------------------------------------------------------
if [ -n "${DISTLOCAL}" ]; then
	cp -v ${TB} ${DISTDIR} >&9
	if [ -n "${DIGEST}" ]; then
		ebuild ${EBUILD} digest >&9 || ewarn "Sorry. creation digest failed"
	fi
else
	einfol 0 "Copy ${TB} to \${DISTFILES}, and run"
	einfol 0 "ebuild \${EBUILD} digest."
	einfol 0
	einfol 0 "Make sure to cvs up and echangelog before a repoman commit."
fi

einfol 3 "Done."

# vim:ai:noet:ts=4:nowrap
