# Copyright 1999-2016 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Id$

EAPI=6

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
	!gnuefi? ( >=sys-boot/udk-2015 )"

DOCS="NEWS.txt README.txt docs/refind docs/Styles"

pkg_setup() {
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
	eapply_user
	[[ $EFIARCH == x64 ]] && PECOFF_HEADER_SIZE='0x228' || PECOFF_HEADER_SIZE='0x220'
	for f in "${S}/Make.common" "${S}"/*/Make.tiano; do
		sed -i -e 's/^\(EDK2BASE\s*=.*\)$/#\1/' \
			-e 's/^\(include .*target.txt.*\)$/#\1/' \
			-e '/^\s*-I \$(EDK2BASE).*$/d' \
			-e 's@^\(TIANO_INCLUDE_DIRS\s*=\s*-I\s*\).*$@\1/usr/include/udk \\@' \
			-e 's/^\(GENFW\s*=\s*\).*$/\1\$(prefix)GenFw/' \
			-e 's@\$(EDK2BASE)/BaseTools/Scripts/gcc4.4-ld-script@/usr/lib/GccBase.lds@' \
			-e 's/^\(TIANO_LDFLAGS\s*=.*\)\\$/\1--defsym=PECOFF_HEADER_SIZE='${PECOFF_HEADER_SIZE}' \\/' \
			"${f}" || die "Failed to patch Tianocore make file in" \
			$(basename $(dirname ${f}))
	done
	for f in "${S}"/*/Make.tiano; do
		sed -i -e 's@^\(EFILIB\s*=\s*\).*$@\1/usr/lib@' \
			-e 's@\$(EFILIB).*/\([^/]*\).lib@-l\1@' \
			-e 's/\(--start-group\s*\$(ALL_EFILIBS)\)/-L \$(EFILIB) \1/' \
			"${f}" || die "Failed to patch Tianocore make file in" \
			$(basename $(dirname ${f}))
	done
	for f in "${S}"/*/AutoGen.c; do
		cat >>"${f}" <<EOF

#define _PCD_TOKEN_PcdFixedDebugPrintErrorLevel  11U
#define _PCD_SIZE_PcdFixedDebugPrintErrorLevel 4
#define _PCD_GET_MODE_SIZE_PcdFixedDebugPrintErrorLevel  _PCD_SIZE_PcdFixedDebugPrintErrorLevel 
#define _PCD_VALUE_PcdFixedDebugPrintErrorLevel  0xFFFFFFFFU
GLOBAL_REMOVE_IF_UNREFERENCED const UINT32 _gPcd_FixedAtBuild_PcdFixedDebugPrintErrorLevel = _PCD_VALUE_PcdFixedDebugPrintErrorLevel;
extern const  UINT32  _gPcd_FixedAtBuild_PcdFixedDebugPrintErrorLevel;
#define _PCD_GET_MODE_32_PcdFixedDebugPrintErrorLevel  _gPcd_FixedAtBuild_PcdFixedDebugPrintErrorLevel
//#define _PCD_SET_MODE_32_PcdFixedDebugPrintErrorLevel  ASSERT(FALSE)  // It is not allowed to set value for a FIXED_AT_BUILD PCD
EOF
	done
}

src_compile() {
	# Make main EFI
	use gnuefi && export all_target=gnuefi || export all_target=tiano
	emake ARCH=${BUILDARCH} ${all_target}

	# Make filesystem drivers
	use gnuefi && export gnuefi_target="_gnuefi"
	for fs in ${FS_USE}; do
		fs=${fs#+}
		if use "${fs}"; then
			einfo "Building ${fs} filesystem driver"
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
	doins "${S}/refind.conf-sample"
	doins -r images icons fonts banners

	if [[ -d "${S}/drivers_${EFIARCH}" ]]; then
		doins -r "${S}/drivers_${EFIARCH}"
	fi

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
