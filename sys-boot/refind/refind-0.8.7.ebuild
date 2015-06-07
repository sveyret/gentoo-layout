# Copyright 1999-2015 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: $

EAPI=5

inherit eutils

DESCRIPTION="rEFInd is an UEFI boot manager"
HOMEPAGE="http://www.rodsbooks.com/refind/"
SRC_URI="mirror://sourceforge/project/${PN}/${PV}/${PN}-src-${PV}.zip"
RESTRICT="primaryuri"

LICENSE="BSD GPL-2 GPL-3 FDL-1.3"
SLOT="0"
KEYWORDS="-* ~amd64"
IUSE="-gnuefi +install +secureboot"

DEPEND="sys-boot/efibootmgr sys-block/parted"
DEPEND="${DEPEND} secureboot? ( app-crypt/sbsigntool )"
DEPEND="${DEPEND} gnuefi? ( >=sys-boot/gnu-efi-3.0.2 )"
DEPEND="${DEPEND} !gnuefi? ( >=sys-boot/edk2-2014.1.1 )"

pkg_setup() {
	for f in /usr/lib/edk2-*; do # Hope last directory is most recent version
		export EFILIB_DIR="${f}"
	done
	export ARCH=$( uname -m | sed s,i[3456789]86,ia32, )
	if [[ ${ARCH} == "x86_64" ]] ; then
		export EFIARCH=x64
	else
		export EFIARCH=${ARCH}
	fi
}

src_prepare() {
	for f in "${S}/Make.tiano" "${S}"/*/Make.tiano; do
		sed -i -e 's/^\(EDK2BASE\s*=.*\)$/#\1/' \
			-e '/^\s*-I \$(EDK2BASE).*$/d' \
			-e 's/^\(include .*target.txt.*\)$/#\1/' \
			-e 's@^\(INCLUDE_DIRS\s*=\s*-I\s*\).*$@\1/usr/include/edk2 \\@' \
			-e 's/^\(GENFW\s*=\s*\).*$/\1\$(prefix)GenFw/' \
			-e 's@\$(EDK2BASE)/BaseTools/Scripts@'${EFILIB_DIR}'@' \
			-e 's@^\(EFILIB\s*=\s*\).*$@\1'${EFILIB_DIR}'@' \
			-e 's@\$(EFILIB).*/\([^/]*\).lib@-l\1@' \
			-e 's/\(--start-group\s*\$(ALL_EFILIBS)\)/-L \$(EFILIB) \1/' \
			"${f}" || die "Failed to patch Tianocore make file in" \
			$(basename $(dirname ${f}))
	done
	epatch "${FILESDIR}/${PV}-install-symlink.patch"
}

src_compile() {
	# Make main EFI
	if use gnuefi; then
		all_target=gnuefi
	else
		all_target=tiano
	fi
	emake ${all_target}

	# Make filesystem drivers
	use gnuefi && export gnuefi_target="_gnuefi"
	for d in ext2 ext4 reiserfs iso9660 hfs ntfs; do # btrfs does not compile
		emake -C "${S}/filesystems" "${d}${gnuefi_target}"
	done
}

src_install() {
	insinto "/usr/share/${P}/refind"
	doins "${S}/refind"/refind*.efi
	doins -r "${S}/drivers_${EFIARCH}"
	doins "${S}/refind.conf-sample"
	doins -r "${S}/icons"
	insinto "/usr/share/${P}/refind/tools_${EFIARCH}"
	doins "${S}/gptsync/gptsync_${EFIARCH}.efi"
	insinto "/usr/share/${P}"
	doins "${S}/install.sh"
	fperms u+x "/usr/share/${P}/install.sh"

	use doc && dohtml -r "${S}/docs"/*
	dodoc "${S}"/{NEWS.txt,COPYING.txt,LICENSE.txt,README.txt,CREDITS.txt}

	insinto "/etc/refind.d"
	doins -r "${S}/keys"

	dosbin "${S}/mkrlconf.sh"
	dosbin "${S}/mvrefind.sh"

	insinto "/usr/share/${P}"
	doins -r "${S}/banners"
	doins -r "${S}/fonts"
	dosym "/usr/share/${P}/install.sh" "/usr/sbin/refind-install"
}

pkg_postinst() {
	use install && "${S}/debian/postinst"
	elog "You can use the command refind-install in order to install rEFInd to"
	elog "a given device."
}

