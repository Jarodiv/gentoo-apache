#!/bin/bash
#
# rolltarball.sh - rolls a tarball for distribution
#
# Copyright 2005 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
#
# Before commiting large changes, or if you don't completely understand a 
# small change you are about to commit, please consult the Primary Maintainer
# first to make sure it won't break things. Thanks!
# 
# Contributors:
#	Michael Stewart <vericgar@gentoo.org> (Primary Maintainer)
#	Christian Parpart <trapni@gentoo.org>
#	Lars Wendler <polynomial-c@gentoo.org>
#
# Changes:
#	05-Jun-2005	Complete rewrite to clean up code
#	20-Apr-2014	Use git instead of svn. Change patchname in ebuild as
#			well
#

# Please increase version number before each commit which includes changes to
# this script.
MYVERSION='2.0'

# ********** Begin functions **********

usage() {
	
	if [ -n "$1" ]
	then
		eerror $1
	else
		cat <<-USAGE_HEADER
			Gentoo Apache Tarball Generator
			Version: ${MYVERSION}
		USAGE_HEADER
	fi

# there are no tabs in the following!!!
	cat <<USAGE

Usage: $0 [options] ebuild

Where options is any of:
-a  --ask           Display what would be done, then ask to do it (default)
-A  --no-ask        Disable ask
-t  --color         Turn on color
-T  --no-color      Turn off color
-c  --copyto=path   Copy tarball to local path (default: /usr/portage/distfiles)
-C  --no-copy       Don't copy tarball
-d  --devspace      Upload to devspace (default)
-D  --no-devspace   Don't upload to devspace
-g  --digest        Create the digest (default)
-G  --no-digest     Don't create the digest
-e  --ebuild        Modify ebuild (default)
-E  --no-ebuild     Don't modify ebuild
-h  --help          Display this output
-m  --mirror        Upload to mirror://gentoo
-M  --no-mirror     Don't upload to mirror://gentoo (default)
-p  --pretend       Only display what would be done
    --quiet         Set verbosity to 0
-q                  Lower verbosity by 1
-s  --datestamp     Use alternate datestamp
-u  --user=username Gentoo Username (Default: auto-detected)
    --verbosity=n   Verbosity Level (0-4)
-v                  Increase verbosity by 1

For convienence, ~/.apache-rolltarball will be sourced so you can set any 
of the following instead of using the command line:

ASK            Ask before doing anything (0 = no, 1 = yes)
COLOR          Output in color (0 = no, 1 = yes)
COPYTO         Local path to copy tarball to (set to blank to disable copy)
G_USER         Gentoo Username
MOD_EBUILD     Modify ebuild (0 = no, 1 = yes)
UPLOAD_DEV     Whether to upload to devspace (0 = no, 1 = yes)
UPLOAD_MIRROR  Whether to upload to gentoo mirrors (0 = no, 1 = yes)
VERBOSE        Level of verbosity (0-3)

USAGE

	exit
}


eerror() {
	echo -e " ${BAD}*${NORMAL} ${*}"
}


die() {
	if [ "$#" -gt 0 ]
	then
		eerror ${*}
	fi
	exit 1
}


einfo() {
	if [ "${VERBOSE}" -ge "1" ]
	then
		echo -e " ${GOOD}*${NORMAL} ${*}"
	fi
}


ebegin() {
	if [ "${VERBOSE}" -ge "1" ]
	then
		echo -e " ${GOOD}*${NORMAL} ${*}..."
	fi
}


eend() {

	if [ "$#" -eq 0 ] || ([ -n "$1" ] && [ "$1" -eq 0 ])
	then
		if [ "${VERBOSE}" -ge "1" ]
		then
			echo -e "${ENDCOL}  ${BRACKET}[ ${GOOD}ok${BRACKET} ]${NORMAL}"
		fi
	else
		retval=$1

		if [ "$#" -ge 2 ]
		then
			shift
			eerror "${*}"
		fi
		if [ "${VERBOSE}" -ge "1" ]
		then
			echo -e "${ENDCOL}  ${BRACKET}[ ${BAD}!!${BRACKET} ]${NORMAL}"
		fi	
		return ${retval}
	fi

}		


ewarn() {
	if [ "${VERBOSE}" -ge "2" ]
	then
		echo -e " ${WARN}*${NORMAL} ${*}"
	fi
}


edebug() {
	if [ "${VERBOSE}" -ge "4" ]
	then
		echo -e " ${HILITE}*${NORMAL} ${*}"
	fi
}


nocolor() {
	COLS="80"
	ENDCOL=" *****>>"
	GOOD=
	WARN=
	BAD=
	NORMAL=
	HILITE=
	BRACKET=
	COLOR=0
	edebug "Color disabled"
}


color() {
	COLS=$(stty size 2> /dev/null)
	COLS=${COLS#* }
	COLS=$((${COLS} - 7))
	ENDCOL=$'\e[A\e['${COLS}'G'
	GOOD=$'\e[32;01m'
	WARN=$'\e[33;01m'
	BAD=$'\e[31;01m'
	NORMAL=$'\e[0m'
	HILITE=$'\e[36;01m'
	BRACKET=$'\e[34;01m'
	COLOR=1
	edebug "Color enabled"
}	

# ********** End functions, begin primary code **********

# Defaults
# If you change these, change usage()
ASK=1
COLOR=1
COPYTO=/usr/portage/distfiles
DIGEST=1
G_USER=
MOD_EBUILD=1
PRETEND=0
UPLOAD_DEV=1
UPLOAD_MIRROR=0
VERBOSE=1

# load configuration
if [ -e ~/.apache-rolltarball ]
then
	. ~/.apache-rolltarball
	edebug "Loaded configuration from ~/.apache-rolltarball"
fi

if [ "${COLOR}" -eq "0" ]
then
	nocolor;
else
	color;
fi

# Process command line
until [ -z "$1" ]
do
	case "$1" in
		--*)
			# long options
			OPTFULL=${1/--/}
			OPT=${OPTFULL%=*}
			VALUE=${OPTFULL#*=}
			case "${OPT}" in
				ask)			ASK=1;;
				no-ask)			ASK=0;;
				color)			color;;
				no-color)		nocolor;;
				copyto)			COPYTO=${VALUE};;
				no-copy)		COPYTO=;;
				datestamp)		DATESTAMP=${VALUE};;
				devspace)		UPLOAD_DEV=1;;
				no-devspace)	UPLOAD_DEV=0;;
				digest)			DIGEST=1;;
				no-digest)		DIGEST=0;;
				ebuild)			MOD_EBUILD=1;;
				no-ebuild)		MOD_EBUILD=0;;
				help)			usage;;
				mirror)			UPLOAD_MIRROR=1;;
				no-mirror)		UPLOAD_MIRROR=0;;
				pretend)		PRETEND=1;;
				quiet)			VERBOSE=0;;
				user)			G_USER=${VALUE};;
				verbosity)		VERBOSE=${VALUE};;
				*)
					usage "Unknown option: --${OPT}"
				;;
			esac
			shift
		;;
		-*)
			# short options
			OPTLIST=${1/-/}
			shift
			while [ -n "${OPTLIST}" ]
			do
				OPT=${OPTLIST:0:1}
				OPTLIST=${OPTLIST#?}
				case "${OPT}" in
					a)	ASK=1;;
					A)	ASK=0;;
					c)	COPYTO=$1; shift;;
					C)	COPYTO=;;
					d)	UPLOAD_DEV=1;;
					D)	UPLOAD_DEV=0;;
					e)	MOD_EBUILD=1;;
					E)	MOD_EBUILD=0;;
					g)	DIGEST=1;;
					G)	DIGEST=0;;
					h)	usage;;
					m)	UPLOAD_MIRROR=1;;
					M)	UPLOAD_MIRROR=0;;
					p)	PRETEND=1;;
					q)	VERBOSE=$((${VERBOSE} - 1));;
					s)	DATESTAMP=$1; shift;;
					t)	color;;
					T)	nocolor;;
					u)	G_USER=$1; shift;;
					v)	VERBOSE=$((${VERBOSE} + 1));;
					*)
						usage "Unknown option: -${OPT}"
					;;
				esac
			done
		;;
		*)
			if [ -n "${EBUILD}" ]
			then
				usage "Only one ebuild can be specified"
			else
				EBUILD=$1
				shift
			fi
		;;
	esac
done

if [ -z "${EBUILD}" ]
then
	usage "You must specify an ebuild"
fi

if [ "${EBUILD##*.}" != "ebuild" ]
then
	usage "You must specify an ebuild"
fi

if [ ! -f ${EBUILD} ]
then
	die "Ebuild ${EBUILD} does not exist or is not a file"
fi

if [ "${VERBOSE}" -lt "0" ]
then
	VERBOSE=0
fi

if [ "${VERBOSE}" -gt "4" ]
then
	VERBOSE=4
fi

if [ "${VERBOSE}" -ge "3" ]
then
	edebug "Program output enabled"
	exec 9>&1
else
	edebug "Program output disabled"
	exec 9>/dev/null
fi

if [ "${ASK}" -eq "1" ]
then
	PRETEND=1
fi

if [ -z "${G_USER}" ]
then
	G_USER="$(git log -1 | grep ^Author | sed 's&.*<\([[:alnum:]\._-]\+\)@.*>&\1&')"
	einfo "Detected Gentoo Developer: ${G_USER}"
fi

edebug "Current configuration:"
edebug "  ASK: ${ASK}"
edebug "  COLOR: ${COLOR}"
edebug "  COPYTO: ${COPYTO}"
edebug "  DIGEST: ${DIGEST}"
edebug "  EBUILD: ${EBUILD}"
edebug "  G_USER: ${G_USER}"
edebug "  MOD_EBUILD: ${MOD_EBUILD}"
edebug "  PRETEND: ${PRETEND}"
edebug "  UPLOAD_DEV: ${UPLOAD_DEV}"
edebug "  UPLOAD_MIRROR: ${UPLOAD_MIRROR}"
edebug "  VERBOSE: ${VERBOSE}"

my_mtime=$(stat --format=%Y $0)

ebegin "Updating tree"
git pull >&9
eend $? "git update failed!" || die

new_mtime=$(stat --format=%Y $0)
if [ "${my_mtime}" -ne "${new_mtime}" ]
then
	einfo "A new version of $0 is available"
	einfo "Please restart $0"
	die
fi

edebug "Detecting settings for tarball based on ebuild name"

EBUILD_BASE=$(basename ${EBUILD})
EBUILD_NAME=${EBUILD_BASE/-[0-9]*/}
TB_NAME="gentoo-${EBUILD_NAME}"
TB_VER=${EBUILD_BASE/${EBUILD_NAME}-/}
TB_VER=${TB_VER/.ebuild/}
DATESTAMP=${DATESTAMP:-$(date +%Y%m%d)}

case ${EBUILD_NAME} in
	apache)
		TREE=${TB_VER%.*}
		TB=${TB_NAME}-${TB_VER}-${DATESTAMP}.tar.bz2
		TB_DIR=${TB_NAME}-${TB_VER}
		;;
	gentoo-webroot-default)
		TREE=gentoo-webroot-default
		TB=gentoo-webroot-default-${TB_VER}.tar.bz2
		TB_DIR=gentoo-webroot-default-${TB_VER}
		MOD_EBUILD=0
		UPLOAD_MIRROR=1
		UPLOAD_DEV=0
		einfo "Have you version-bumped gentoo-webroot-default?"
		einfo "If not, press Ctrl-C now and do so, specifying the new ebuild"
		sleep 5
		;;
	*)	
		die "Don't know what to do for ebuild: ${EBUILD_NAME}";;
esac

edebug "  TREE: ${TREE}"
edebug "  TB: ${TB}"
edebug "  TB_DIR: ${TB_DIR}"

# simply returns true or false based on whether we are in pretend mod or not
pretend() {
	if [ "${PRETEND}" -eq 1 ]
	then
		true
		return $?
	else
		false
		return $?
	fi
}


# we put all this in a function so that we can simply call it again when
# the result of asking is yes.
CURTIME=`date -u`
build_tarball() {

	pretend && einfo "Actions to be taken:"

	pretend && einfo "  Create ${TB} from ${TREE}/"
	pretend || {
		ebegin "Creating ${TB} from ${TREE}/"
		edebug "Copy recursive, hard-link where possible: ${TREE} -> ${TB_DIR}"
		cp -Rl ${TREE} ${TB_DIR} >&9 || eend $? "Copy failed" || die
		edebug "Create ${TB_DIR}/DATESTAMP with current time (${CURTIME}), packager (${G_USER}), and script version (${MYVERSION})"
		echo ${CURTIME} > ${TB_DIR}/DATESTAMP
		echo "Packaged by ${G_USER}" >> ${TB_DIR}/DATESTAMP
		echo "$0 v${MYVERSION}" >> ${TB_DIR}/DATESTAMP
		edebug "Create bzip2-ed tarball ${TB} from ${TB_DIR} excluding vcs files"
		tar --create --bzip2 --verbose --exclude-vcs --exclude=*~ --file ${TB} ${TB_DIR} >&9
		eend $? "Tarball creation failed" || die
		edebug "Remove temporary directory" 
		rm -rf ${TB_DIR} || ewarn "Couldn't clean up, manually remove ${TB_DIR}/"
	}

	if [ -n "${COPYTO}" ]
	then
		if [ -d ${COPYTO} -a -w ${COPYTO} ]
		then
			pretend && einfo "  Copy ${TB} to ${COPYTO}"
			pretend || {
				ebegin "Copying ${TB} to ${COPYTO}"
				cp ${TB} ${COPYTO} >&9
				eend $?
			}
		else
			ewarn "${COPYTO} is not a directory or not writable, skipping copy"
		fi
	else
		edebug "Copy not enabled"
	fi

	if [ "${UPLOAD_DEV}" -eq 1 ]
	then
		pretend && einfo "  Upload ${TB} to"
		pretend && einfo "      http://dev.gentoo.org/~${G_USER}/dist/apache/"
		pretend || {
			einfo "Uploading ${TB} to"
			ebegin "    http://dev.gentoo.org/~${G_USER}/dist/apache/"
			edebug "Making directories on dev.gentoo.org: ~/public_html/dist/apache"
			ssh ${G_USER}@dev.gentoo.org 'mkdir -pm 0755 ~/public_html/dist/apache/' >&9 || eend $? "Failed to make directories" || die
			
			edebug "scp ${TB} ${G_USER}@dev.gentoo.org:~/public_html/dist/apache"
			scp ${TB} ${G_USER}@dev.gentoo.org:~/public_html/dist/apache >&9 || eend $? "Failed to upload" || die
			edebug "Setting tarball permissions to 0644"
			ssh ${G_USER}@dev.gentoo.org "chmod 0755 ~/public_html/dist ~/public_html/dist/apache" && ssh ${G_USER}@dev.gentoo.org "chmod 0644 ~/public_html/dist/apache/${TB}"
			eend $? "Failed to set permissions" || die
		}
	else
		edebug "Upload to devspace not enabled"
	fi

	if [ "${UPLOAD_MIRROR}" -eq 1 ]
	then
		pretend && einfo "  Upload ${TB} to mirror://gentoo/"
		pretend || {
			ebegin "Uploading ${TB} to mirror://gentoo/"
			edebug "scp ${TB} ${G_USER}@dev.gentoo.org:/space/distfiles-local"
			scp ${TB} ${G_USER}@dev.gentoo.org:/space/distfiles-local >&9 || eend $? "Failed to upload" || die
			edebug "Setting tarball permissions to 0644"
			ssh ${G_USER}@dev.gentoo.org "chmod 0644 /space/distfiles-local/${TB}"
			eend $? "Failed to set permissions" || die
			einfo "Please remember it can take up to 24 hours for full propogation"
			einfo "Make sure the tarball is available before marking a package stable"
		}
	else
		edebug "Upload to mirrors not enabled"
	fi

	if [ "${MOD_EBUILD}" -eq 1 ]
	then
		if [ -r ${EBUILD} ]
		then
			pretend && einfo "  Update GENTOO_PATCHSTAMP, GENTOO_DEVELOPER and GENTOO_PATCHNAME"
			pretend || {
				ebegin "Updating GENTOO_PATCHSTAMP, GENTOO_DEVELOPER and GENTOO_PATCHNAME"
				sed -i -e "s/GENTOO_PATCHSTAMP=\".*\"/GENTOO_PATCHSTAMP=\"${DATESTAMP}\"/" ${EBUILD} && 
				sed -i -e "s/GENTOO_DEVELOPER=\".*\"/GENTOO_DEVELOPER=\"${G_USER}\"/" ${EBUILD} &&
				sed -i -e "s/GENTOO_PATCHNAME=\".*\"/GENTOO_PATCHNAME=\"${TB_NAME}-${TB_VER}\"/" ${EBUILD}
				eend $? "Failed to modify ebuild" || {
					einfo "It's highly recommended that you delete the ebuild"
					einfo "and cvs up and then modify the ebuild manually."
					die
				}
			}
		else
			ewarn "Unable to write to ebuild - skipping modification"
		fi
	else
		edebug "Modify ebuild not enabled"
	fi
	
	if [ "${DIGEST}" -eq 1 ]
	then
		pretend && einfo "  Regenerate digests"
		pretend || {
			ebegin "Regenerating digests"
			ebuild --force ${EBUILD} manifest >&9
			eend $?
		}
	else
		edebug "Regenerate digest not enabled"
	fi
	
	pretend && einfo "No actions actually taken"
	if [ "${ASK}" -eq 1 ]
	then
		einfo "Would you like to perform the above actions?"
		echo -n "Type 'Yes' or 'No'> "
		read ask_in
		if [ "${ask_in}" == "Yes" -o "${ask_in}" == "yes" ]
		then
			ASK=0
			PRETEND=0
			build_tarball
		fi
	fi

}

build_tarball

# vim:ai:noet:ts=4:nowrap
