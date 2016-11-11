# Copyright 1999-2016 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Id$

EAPI=6

DESCRIPTION="The base layout for the project MisybaG"
HOMEPAGE="https://github.com/sveyret/misybag-baselayout"

SRC_URI="https://github.com/sveyret/${PN}/archive/v${PV}.tar.gz -> ${P}.tar.gz"

LICENSE="GPL-3"
SLOT="0"
KEYWORDS="amd64 arm arm64 x86"
IUSE=""

pkg_preinst() {
	if [[ -d "${ROOT}"/root ]]; then
		find "${D}" -name "*.template" -exec rm -f {} \;
	else
		find "${D}" -name "*.template" -exec sh -c 'mv ${0} ${0%.template}' {} \;
	fi
}
