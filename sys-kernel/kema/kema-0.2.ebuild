# Copyright 1999-2016 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Id$

EAPI=5

DESCRIPTION="kema, the Gentoo kernel manager"
HOMEPAGE="https://github.com/sveyret/kema"

SRC_URI="https://github.com/sveyret/${PN}/archive/v${PV}.tar.gz"

LICENSE="GPL-3"
SLOT="0"
KEYWORDS="~amd64"
KEMA_LANG="en en_US fr"
IUSE=""

for lang in ${KEMA_LANG}; do
	IUSE="${IUSE} linguas_${lang}"
done

src_install() {
	dosbin "usr/sbin/kema"
	insinto "/usr/libexec/${PN}"
	doins "usr/libexec/${PN}/kema-"*
	insinto "/usr/libexec/${PN}/bootloader"
	doins "usr/libexec/${PN}/bootloader/"*
	insinto "/etc/${PN}"
	doins "etc/${PN}/"*
	dodir "var/lib/${PN}"

	# Install language pack
	for lang in ${KEMA_LANG}; do
		if [[ ${lang} != "en" ]] && [[ ${lang} != "en_US" ]] && use linguas_${lang}; then
			domo po/${lang}.mo
		fi
	done
}
