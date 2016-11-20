# Copyright 1999-2016 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Id$

EAPI=6

DESCRIPTION="MisybaG, mini-system based on Gentoo"
HOMEPAGE="https://github.com/sveyret/misybag"

SRC_URI="https://github.com/sveyret/${PN}/archive/v${PV}.tar.gz -> ${P}.tar.gz"
RESTRICT="primaryuri"

LICENSE="GPL-3"
SLOT="0"
KEYWORDS="amd64 arm arm64 x86"
IUSE="l10n_en l10n_fr"

inherit eutils

src_configure() {
	# Set prefix to Makefile
	[[ -z "${EPREFIX}" ]] || sed -i -e "s#PREFIX=#&${EPREFIX}#" "${S}"/Makefile

	# No automatic configuration, so manually remove unneeded language files
	local lang_file
	local lang
	for lang_file in po/*.po; do
		lang=$(basename "${lang_file}" .po)
		if ! use l10n_${lang}; then
			rm "${lang_file}"
		fi

		# QA check that we did not forget a language flag
		if ! echo "${IUSE}" | grep -P '(^|\ )l10n_'${lang}'(\ |$)' >/dev/null; then
			eqawarn "Language ${lang} is not in IUSE flags."
		fi
	done
}
