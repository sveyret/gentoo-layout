# Copyright 2020 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=7

inherit desktop xdg-utils

DESCRIPTION="Crypto-currency software to manage libre currency - desktop"
HOMEPAGE="https://duniter.org/"

JOB_ID=40349
SRC_URI="amd64? ( https://git.duniter.org/nodes/typescript/duniter/-/jobs/${JOB_ID}/artifacts/raw/work/bin/${PN%%-bin}-v${PV}-linux-x64.tar.gz -> ${P}.tar.gz )"

LICENSE="AGPL-3"
SLOT="0"
KEYWORDS="~amd64"

RDEPEND="
	!net-p2p/duniter
"

RESTRICT="primaryuri"

src_unpack() {
	mkdir -p "${S}" || die
	pushd "${S}" >/dev/null || die
	unpack ${A}
	popd >/dev/null || die
}

src_compile() {
	# Update path to icon
	sed -i "s:^\\(Icon\\s*=\\s*\\)/.*/\\([^/]*\\)\\.[^.]*$:\\1\\2:" \
		extra/desktop/usr/share/applications/duniter.desktop || die
}

src_install() {
	local target="${EPREFIX%/}/opt/${PN}"

	# Install desktop shortcut
	doicon -s scalable duniter.png
	domenu extra/desktop/usr/share/applications/duniter.desktop

	# Prepare application move
	mv extra "${WORKDIR}" || die
	cd "${WORKDIR}" || die

	# Install application
	dodir ${target%/*}
	mv "${S}" "${D}${target}" || die
	fowners -R 0:0 "${target}"
	dosym "${target}/duniter-desktop" "${EPREFIX%/}/usr/bin/duniter-desktop"
}

pkg_postinst() {
	xdg_icon_cache_update
	xdg_desktop_database_update
}

pkg_postrm() {
	xdg_icon_cache_update
	xdg_desktop_database_update
}
