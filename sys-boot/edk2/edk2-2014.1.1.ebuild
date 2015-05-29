# Copyright 1999-2015 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: $

EAPI=5

inherit versionator

DESCRIPTION="Tianocore UEFI development kit"
HOMEPAGE="http://www.tianocore.org/edk2/"
MY_MV=$(get_version_component_range 1)
MY_MV="UDK${MY_MV}"
MY_SP=$(get_version_component_range 2)
MY_SP="SP${MY_SP}"
MY_P=$(get_version_component_range 3)
MY_P="P${MY_P}"
MY_PV="${MY_MV}.${MY_SP}.${MY_P}"
SRC_URI="mirror://sourceforge/project/${PN}/${MY_MV}_Releases/${MY_PV}/${MY_PV}.Complete.MyWorkSpace.zip"
RESTRICT="primaryuri"

LICENSE="BSD"
SLOT="0"
KEYWORDS="-* ~amd64"
IUSE="-debug -demo"

DEPEND="app-arch/unzip dev-lang/nasm"

# We know this file contains WX sections, but we are in UEFI, before any kernel
# is loaded, before being in protected mode.
QA_EXECSTACK="usr/lib*/BaseLib.lib*"

pkg_setup() {
	# Calculate toolchain tag
	GCC_VERS=$(gcc --version | head -1 | sed "s/.*)//")
	GCC_VERS=$(get_version_component_range 1-2 ${GCC_VERS})
	GCC_VERS=$(delete_all_version_separators ${GCC_VERS})
	export toolchain_tag="GCC${GCC_VERS}"
	export ARCH="X64"
	use debug && export compile_mode="DEBUG" || export compile_mode="RELEASE"
}

src_unpack() {
	unpack ${A}
	cd "${WORKDIR}"
	unzip "UDK2014.SP1.P1.MyWorkSpace.zip"
	mv "${WORKDIR}/MyWorkSpace" "${S}"
	mv "${WORKDIR}/BaseTools(Unix).tar" "${S}"
	cd "${S}"
	tar -xf "BaseTools(Unix).tar"
}

src_prepare() {
	make -C BaseTools || die "Impossible to compile EDK2 base tools"
	export EDK_TOOLS_PATH="${S}/BaseTools"
	. edksetup.sh BaseTools
}

src_configure() {
	sed -i -e "s/^\(TOOL_CHAIN_TAG\s*=\).*\$/\\1 ${toolchain_tag}/" \
		"${S}/Conf/target.txt" || die "Could not set tool chain"
	sed -i -e \
		"s!^\(ACTIVE_PLATFORM\s*=\).*\$!\\1 MdeModulePkg\\/MdeModulePkg.dsc!" \
		"${S}/Conf/target.txt" || die "Could not set platform"
	sed -i -e \
		"s/^\(TARGET\s*=\).*\$/\\1 ${compile_mode}/" \
		"${S}/Conf/target.txt" || die "Could not set target compile mode"
	sed -i -e \
		"s/^\(TARGET_ARCH\s*=\).*\$/\\1 ${ARCH}/" \
		"${S}/Conf/target.txt" || die "Could not set target architecture"
}

src_compile() {
	if use demo; then
		BUILD_TARGET=all
	else
		BUILD_TARGET=libraries
	fi
	build ${BUILD_TARGET} || die "Could not compile environment"
	# TODO Sometimes a package will not use the user's ${CFLAGS} or ${LDFLAGS}.
	# TODO This must be worked around.
	# TODO See https://devmanual.gentoo.org/ebuild-writing/functions/src_compile/building/index.html
}

src_install() {
	BUILD_DIR="${S}/Build/MdeModule/${compile_mode}_${toolchain_tag}"
	LIB_DIR="${BUILD_DIR}/X64/MdePkg/Library"
	for l in "${LIB_DIR}"/*/*/OUTPUT/*.lib; do
		dolib "${l}"
	done
	INCLUDE_DIR="${S}/MdePkg/Include"
	INCLUDE_DEST="/usr/include/edk2"
	for s in "" /Uefi /Guid /IndustryStandard /Library /Protocol /${ARCH}; do
		dodir "${INCLUDE_DEST}${s}"
		insinto "${INCLUDE_DEST}${s}"
		for h in "${INCLUDE_DIR}${s}"/*.h; do
			doins "${h}"
		done
	done
	# TODO Must install demo somewhere, but Makefiles for demo needs to be
	# TODO modified.

	# TODO  * QA Notice: Package triggers severe warnings which indicate that it
	# TODO  *            may exhibit random runtime failures.
	# TODO  * /usr/include/bits/string3.h:84:70: warning: call to void* __builtin___memset_chk(void*, int, long unsigned int, long unsigned int) will always overflow destination buffer [enabled by default]
	# TODO  * /usr/include/bits/string3.h:84:70: warning: call to void* __builtin___memset_chk(void*, int, long unsigned int, long unsigned int) will always overflow destination buffer [enabled by default]
}

pkg_postinst() {
	elog "Installation done for ${ARCH}"
	# TODO If demo is selected, display where demo projects can be found.
}

