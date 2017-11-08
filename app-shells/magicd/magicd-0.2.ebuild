# Copyright 1999-2017 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2

EAPI=6

DESCRIPTION="MagiCd, the bash enhanced cd"
HOMEPAGE="https://github.com/sveyret/MagiCd"

SRC_URI="https://github.com/sveyret/${PN}/archive/v${PV}.tar.gz -> ${P}.tar.gz"

LICENSE="GPL-3"
SLOT="0"
KEYWORDS="~amd64"
IUSE="l10n_en l10n_fr"

inherit eutils

src_configure() {
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
