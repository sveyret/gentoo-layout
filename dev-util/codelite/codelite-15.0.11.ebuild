# Copyright 1999-2022 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=7

WX_GTK_VER=3.0-gtk3

inherit cmake xdg wxwidgets

DESCRIPTION="A Free, open source, cross platform C, C++, PHP and Node.js IDE"
HOMEPAGE="http://codelite.org/"

SRC_URI="https://github.com/eranif/${PN}/archive/refs/tags/${PV}.tar.gz -> ${P}.tar.gz"
RESTRICT="primaryuri"

LICENSE="GPL-2"
SLOT="0"
IUSE=""

KEYWORDS="~amd64 ~x86"

RDEPEND=">=x11-libs/wxGTK-3.0.0:3.0-gtk3 net-libs/libssh dev-db/sqlite:3"
DEPEND="${RDEPEND}"
BDEPEND=">=dev-util/cmake-3.16"

CMAKE_BUILD_TYPE="Release"

src_prepare() {
	setup-wxwidgets
	cmake_src_prepare
	eapply_user
}

pkg_postinst() {
	xdg_pkg_postinst
}

pkg_postrm() {
	xdg_pkg_postrm
}
