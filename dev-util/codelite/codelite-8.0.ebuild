# Copyright 1999-2015 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: $

EAPI=5

inherit git-r3 cmake-utils

EGIT_REPO_URI="https://github.com/eranif/${PN}.git"
EGIT_COMMIT="${PV}"

LICENSE="GPL-2"
SLOT="0"
IUSE=""

KEYWORDS="~amd64"

RDEPEND=">=x11-libs/wxGTK-3.0.0.0"

