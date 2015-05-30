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
IUSE="-debug -doc -examples"

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
	export ARCH_SIZE="64"
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
	use doc && unzip "${WORKDIR}/Documents/MdeModulePkg Document.zip"
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
	if use examples; then
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
	BUILD_DIR="${S}/Build/MdeModule/${compile_mode}_${toolchain_tag}/${ARCH}"

	insinto "/usr/lib${ARCH_SIZE}/${PF}"
	doins "${BUILD_DIR}/MdePkg/Library"/*/*/OUTPUT/*.lib
	doins "${S}/BaseTools/Scripts"/gcc*-ld-script

	INCLUDE_DIR="${S}/MdePkg/Include"
	INCLUDE_DEST="/usr/include/edk2"
	for f in "" /Uefi /Guid /IndustryStandard /Library /Protocol /${ARCH}; do
		insinto "${INCLUDE_DEST}${f}"
		doins "${INCLUDE_DIR}${f}"/*.h
	done

	if use doc; then
		dohtml -r "${S}/html"/*
	fi

	if use examples; then
		for f in "${S}/MdeModulePkg/Application"/*; do
			EXAMPLE_DIR=$(basename "${f}")
			EX_OUTPUT="${BUILD_DIR}/MdeModulePkg/Application"
			EX_OUTPUT="${EX_OUTPUT}/${EXAMPLE_DIR}/${EXAMPLE_DIR}"
			docinto "examples/${EXAMPLE_DIR}"
			find "${f}" -name '*.h' -exec dodoc '{}' +
			find "${f}" -name '*.c' -exec dodoc '{}' +
			createMakefile "${f}/Makefile" "${EXAMPLE_DIR}" \
				"${EX_OUTPUT}/GNUmakefile"
			dodoc "${f}/Makefile"
			dodoc "${EX_OUTPUT}/DEBUG"/AutoGen.*
		done
	fi

	# TODO  * QA Notice: Package triggers severe warnings which indicate that it
	# TODO  *            may exhibit random runtime failures.
	# TODO  * /usr/include/bits/string3.h:84:70: warning: call to void* __builtin___memset_chk(void*, int, long unsigned int, long unsigned int) will always overflow destination buffer [enabled by default]
	# TODO  * /usr/include/bits/string3.h:84:70: warning: call to void* __builtin___memset_chk(void*, int, long unsigned int, long unsigned int) will always overflow destination buffer [enabled by default]
}

pkg_postinst() {
	elog "Installation done for ${ARCH}"
	use doc && \
		elog "You can find documentation in /usr/share/doc/${PF}/html"
	use examples && \
		elog "You can find examples in /usr/share/doc/${PF}/examples"
}

##
# Parameters :
# 1 - Name of the file to create.
# 2 - Name of the module.
# 3 - Name of the generated GNUmakefile
createMakefile() {
	cat >${1} <<EOF
EXEC=${2}.efi
SRC=\$(wildcard *.c)
OBJ=\$(SRC:.c=.o)
EFIINC=/usr/include/edk2
CFLAGS=-g -fshort-wchar -fno-strict-aliasing -Wall -Werror -Wno-array-bounds -ffunction-sections -fdata-sections -c -include AutoGen.h -DSTRING_ARRAY_NAME=${2}Strings -m64 -fno-stack-protector "-DEFIAPI=__attribute__((ms_abi))" -DNO_BUILTIN_VA_FUNCS -mno-red-zone -Wno-address -mcmodel=large -Wno-address -Wno-unused-but-set-variable
LIB=/usr/lib64/${PF}
STATIC_LIBRARY_FILES =  \\
EOF

	perl -ne 'if( m/^STATIC_LIBRARY_FILES\s*=/ ){ $static=1; }elsif( $static ){ if( m!^\s*\$\(BIN_DIR\).*(/[^/]*\.lib)! ){ print "\t\$(LIB)${1} \\\n" }else{ $static=0; }}' >>${1} <${3}

	cat >>${1} <<EOF

EFI_LDS=\$(LIB)/gcc4.4-ld-script
LDFLAGS=-nostdlib -n -q --gc-sections -T \$(EFI_LDS) --entry _ModuleEntryPoint -u _ModuleEntryPoint -shared -Bsymbolic -lefi -L \$(STATIC_LIBRARY_FILES)

all:	\$(EXEC)

clean:
	@rm -rf *.o *.so

mrproper: clean
	@rm -rf \$(EXEC)

%.so:	\$(OBJ)
	@ld \$(LDFLAGS) \$^ -o \$@

%.efi:	%.so
	@objcopy -j .text -j .sdata -j .data -j .dynamic -j .dynsym  -j .rel \\
	 -j .rela -j .reloc --target=efi-app-x86_64 \$^ \$@

.PHONY: all clean mrproper
EOF
}
