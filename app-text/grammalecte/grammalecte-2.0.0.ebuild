# Copyright 1999-2021 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=7

PYTHON_COMPAT=( python3_{5,6,7,8,9} )
inherit distutils-r1

DESCRIPTION="French grammar checker"
HOMEPAGE="https://grammalecte.net/"
SRC_URI="https://grammalecte.net/${PN}/zip/Grammalecte-fr-v${PV}.zip"
RESTRICT="primaryuri"

LICENSE="GPL-3"
SLOT="0"
KEYWORDS="~amd64 ~x86"

S="${WORKDIR}"
