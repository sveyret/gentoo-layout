# Copyright 1999-2016 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Id$

EAPI=6

DESCRIPTION="kema, the Gentoo kernel manager"
HOMEPAGE="https://github.com/sveyret/kema"

SRC_URI="https://github.com/sveyret/${PN}/archive/v${PV}.tar.gz -> ${P}.tar.gz"

LICENSE="GPL-3"
SLOT="0"
KEYWORDS="amd64"
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

pkg_postinst() {
	if [[ -z "${REPLACING_VERSIONS}" ]]; then
		elog "You will need to emerge"
		elog "sys-kernel/genkernel"
		elog "if you want kema to generate your initramfs"
		elog ""
		elog "Do not forget to update configuration file in:"
		elog "/etc/${PN}"
	fi
}
