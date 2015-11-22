# Copyright 1999-2015 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Id$

EAPI=5

inherit eutils

DESCRIPTION="The rEFInd UEFI Boot Manager by Rod Smith"
HOMEPAGE="http://www.rodsbooks.com/refind/"

SRC_URI="mirror://sourceforge/project/${PN}/${PV}/${PN}-src-${PV}.tar.gz"

LICENSE="BSD GPL-2 GPL-3 FDL-1.3"
SLOT="0"
KEYWORDS="~amd64 ~x86"
FS_USE="btrfs +ext2 +ext4 hfs +iso9660 ntfs reiserfs"
IUSE="${FS_USE} -gnuefi doc"

DEPEND="gnuefi? ( >=sys-boot/gnu-efi-3.0.2 )
	!gnuefi? ( >=sys-boot/edk2-2014.1.1 )"

DOCS="NEWS.txt README.txt docs/refind docs/Styles"

pkg_setup() {
	for f in /usr/lib/edk2-*; do # Hope last directory is most recent version
		export EFILIB_DIR="${f}"
	done
	if use x86 ; then
		export EFIARCH=ia32
		export BUILDARCH=ia32
	elif use amd64; then
		export EFIARCH=x64
		export BUILDARCH=x86_64
	else
		# Try to support anyway
		export BUILDARCH=$( uname -m | sed s,i[3456789]86,ia32, )
		if [[ ${BUILDARCH} == "x86_64" ]] ; then
			export EFIARCH=x64
		else
			export EFIARCH=${ARCH}
		fi
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
	# Make refind-install "symlink-proof"
	epatch "${FILESDIR}/${PV}-refind-install-symlink.patch"
}

src_compile() {
	# Make main EFI
	if use gnuefi; then
		all_target=gnuefi
	else
		all_target=tiano
	fi
	emake ARCH=${BUILDARCH} ${all_target}

	# Make filesystem drivers
	use gnuefi && export gnuefi_target="_gnuefi"
	for fs in ${FS_USE}; do
		fs=${fs#+}
		if use "${fs}"; then
			einfo "Building ${fs} filesystem driver"
			rm -f "${S}/filesystems/fsw_efi.o"
			emake -C "${S}/filesystems" ARCH=${BUILDARCH} ${fs}${gnuefi_target}
		fi
	done

}

src_install() {
	exeinto "/usr/share/${P}"
	doexe refind-install
	dosym "/usr/share/${P}/refind-install" "/usr/sbin/refind-install"

	dodoc "${S}"/{COPYING.txt,LICENSE.txt,CREDITS.txt}
	if use doc; then
		doman "${S}/docs/man/"*
		dodoc -r ${DOCS}
	fi

	insinto "/usr/share/${P}/refind"
	doins "${S}/refind/refind_${EFIARCH}.efi"
	doins -r "${S}/drivers_${EFIARCH}"
	doins "${S}/refind.conf-sample"
	doins -r images icons fonts banners

	insinto "/usr/share/${P}/refind/tools_${EFIARCH}"
	doins "${S}/gptsync/gptsync_${EFIARCH}.efi"

	insinto "/etc/refind.d"
	doins -r "${S}/keys"

	dosbin "${S}/mkrlconf"
	dosbin "${S}/mvrefind"
}

pkg_postinst() {
	elog "rEFInd has been built and installed into /usr/share/${P}"
	elog "You will need to use the command 'refind-install' to install"
	elog "the binaries into your EFI System Partition"
	if [[ -z "${REPLACING_VERSIONS}" ]]; then
		elog ""
		elog "refind-install requires additional packages to be fully functional:"
		elog " app-crypt/sbsigntool for binary signing for use with SecureBoot"
		elog " sys-boot/efibootmgr for writing to NVRAM"
		elog " sys-block/parted for automatic ESP location and mount"
		elog ""
		elog "A sample configuration can be found at"
		elog "/usr/share/${P}/refind/refind.conf-sample"
	else
		ewarn "Note that this will not update any EFI binaries on your EFI"
		ewarn "System Partition - this needs to be done manually."
	fi
}
