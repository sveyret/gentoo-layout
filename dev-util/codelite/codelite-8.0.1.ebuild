# Copyright 1999-2015 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: $

EAPI=5

inherit versionator cmake-utils

MY_GIT_SITE="https://codeload.github.com/eranif"
MY_VERSION=$(replace_version_separator 2 '-')
SRC_URI="${MY_GIT_SITE}/${PN}/tar.gz/${MY_VERSION} -> ${P}.tar.gz"
RESTRICT="primaryuri"

LICENSE="GPL-2"
SLOT="0"
IUSE=""

KEYWORDS="-* ~amd64 ~x86"

RDEPEND=">=x11-libs/wxGTK-3.0.0 net-libs/libssh"
DEPEND="${RDEPEND}"

S="${WORKDIR}/${PN}-${MY_VERSION}"

pkg_setup() {
	WXCONFIG=$(which wx-config)
	[[ -z ${WXCONFIG} ]] && \
		die "wx-config tool not found in path. Compilation cannot proceed."
	WXVERSION=$(${WXCONFIG} --version)
	if [[ $(get_major_version ${WXVERSION}) -lt 3 ]]; then
		eerror "Current version of wxWidgets is ${WXVERSION} while codelite"
		eerror "requires at least version 3.0.0."
		eerror "Please run the following command in order to list available"
		eerror "versions:"
		eerror "  eselect wxwidgets list"
		eerror "and the following command to select a suitable version:"
		eerror "  eselect wxwidgets set <number>"
		eerror
		die "You need to select suitable version for wxWidgets"
	fi
}

src_prepare() {
	sed -i -e 's/\(\s\+\)\(\S\+icon-theme\.cache\)/\1\\$ENV{DESTDIR}\/\2/' \
		"${S}/LiteEditor/CMakeLists.txt" || die "Failed to patch source"
}

