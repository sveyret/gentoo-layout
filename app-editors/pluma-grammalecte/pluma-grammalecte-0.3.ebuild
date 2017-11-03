# Copyright 1999-2017 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2

EAPI=6

DESCRIPTION="Grammalecte plugin for pluma"
HOMEPAGE="https://github.com/sveyret/pluma-grammalecte"

SRC_URI="https://github.com/sveyret/${PN}/archive/v${PV}.tar.gz -> ${P}.tar.gz"

LICENSE="GPL-3"
SLOT="0"
KEYWORDS="~amd64"

RDEPEND="
	app-editors/pluma[python]
	app-text/grammalecte-bin
"
