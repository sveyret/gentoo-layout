# Copyright 1999-2017 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2

EAPI=6

DESCRIPTION="French grammar checker"
HOMEPAGE="https://www.dicollecte.org/"
SRC_URI="http://www.dicollecte.org/grammalecte/zip/Grammalecte-fr-v${PV}.zip"
RESTRICT="primaryuri"

LICENSE="GPL-3"
SLOT="0"
KEYWORDS="~amd64 ~x86"

RDEPEND=">=dev-lang/python-3.3"

S="${WORKDIR}"

src_install() {
	local dest="/opt/grammalecte"
	local ddest="${ED}${dest#/}"

	dodir "${dest}"
	cp -pPR * "${ddest}" || die
}
