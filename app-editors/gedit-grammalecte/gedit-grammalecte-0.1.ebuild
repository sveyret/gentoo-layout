# Copyright 1999-2021 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=7

inherit multilib

DESCRIPTION="Grammalecte plugin for gedit"
HOMEPAGE="https://github.com/sveyret/gedit-grammalecte"

SRC_URI="https://github.com/sveyret/${PN}/archive/v${PV}.tar.gz -> ${P}.tar.gz"

LICENSE="GPL-3"
SLOT="0"
KEYWORDS="~amd64"

RDEPEND="
	app-editors/gedit[python]
	app-text/grammalecte
"

src_install() {
	emake DESTDIR="${D}" PLUGIN_INSTALL="/usr/$(get_libdir)" install
	einstalldocs
}
