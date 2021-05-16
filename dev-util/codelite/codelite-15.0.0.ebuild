# Copyright 1999-2021 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=7

WX_GTK_VER=3.0-gtk3

inherit cmake xdg-utils wxwidgets

DESCRIPTION="A Free, open source, cross platform C, C++, PHP and Node.js IDE"
HOMEPAGE="http://codelite.org/"

GIT_SOURCE_URL="https://codeload.github.com/eranif"
[[ $(ver_cut 3) -eq 0 ]] && SEEN_VERSION=$(ver_cut 1-2)
SEEN_VERSION=$(ver_rs 2 '-' "${SEEN_VERSION}")

SRC_URI="${GIT_SOURCE_URL}/${PN}/tar.gz/${SEEN_VERSION} -> ${P}.tar.gz"
RESTRICT="primaryuri"

LICENSE="GPL-2"
SLOT="0"
IUSE=""

KEYWORDS="~amd64 ~x86"

RDEPEND=">=x11-libs/wxGTK-3.0.0:3.0-gtk3 net-libs/libssh dev-db/sqlite:3"
DEPEND="${RDEPEND}"

S="${WORKDIR}/${PN}-${SEEN_VERSION}"

src_prepare() {
	setup-wxwidgets
	cmake_src_prepare
	eapply_user
}

pkg_postinst() {
	xdg_icon_cache_update
}

pkg_postrm() {
	xdg_icon_cache_update
}

