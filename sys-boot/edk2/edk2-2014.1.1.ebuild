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
QA_EXECSTACK="usr/lib*/libBaseLib.a*"

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
	unzip -d"${WORKDIR}" "${MY_PV}.MyWorkSpace.zip" \
		|| die "Failed to unzip workspace"
	mv "${WORKDIR}/MyWorkSpace" "${S}"
	tar -C "${S}" -xf "${WORKDIR}/BaseTools(Unix).tar" \
		|| die "Failed to untar base tools"
	if use doc; then
		mkdir -p"${S}/doc"
		unzip -d"${S}/doc" \
			"${WORKDIR}/Documents/MdeModulePkg Document.zip" \
			|| die "Failed to unzip documentation"
		mv "${S}/doc/html" "${S}/doc/MdeModulePkg"
		unzip -d"${S}/doc" \
			"${WORKDIR}/Documents/MdePkg Document.zip" \
			|| die "Failed to unzip documentation"
		mv "${S}/doc/html" "${S}/doc/MdePkg"
	fi
}

src_prepare() {
	make -C BaseTools || die "Failed to compile EDK2 base tools"
	export EDK_TOOLS_PATH="${S}/BaseTools"
	. edksetup.sh BaseTools
}

src_configure() {
	sed -i -e "s/^\(TOOL_CHAIN_TAG\s*=\).*\$/\\1 ${toolchain_tag}/" \
		"${S}/Conf/target.txt" || die "Failed to set tool chain"
	sed -i -e \
		"s!^\(ACTIVE_PLATFORM\s*=\).*\$!\\1 MdeModulePkg\\/MdeModulePkg.dsc!" \
		"${S}/Conf/target.txt" || die "Failed to set platform"
	sed -i -e \
		"s/^\(TARGET\s*=\).*\$/\\1 ${compile_mode}/" \
		"${S}/Conf/target.txt" || die "Failed to set target compile mode"
	sed -i -e \
		"s/^\(TARGET_ARCH\s*=\).*\$/\\1 ${ARCH}/" \
		"${S}/Conf/target.txt" || die "Failed to set target architecture"
}

src_compile() {
	if use examples; then
		BUILD_TARGET=all
	else
		BUILD_TARGET=libraries
	fi
	build ${BUILD_TARGET} || die "Failed to compile environment"
	# TODO Sometimes a package will not use the user's ${CFLAGS} or ${LDFLAGS}.
	# TODO This must be worked around.
	# TODO See https://devmanual.gentoo.org/ebuild-writing/functions/src_compile/building/index.html
}

src_install() {
	BUILD_DIR="${S}/Build/MdeModule/${compile_mode}_${toolchain_tag}/${ARCH}"

	insinto "/usr/lib${ARCH_SIZE}/${PF}"
	for f in "${BUILD_DIR}/MdePkg/Library"/*/*/OUTPUT/*.lib; do
		newins "${f}" lib$(basename "${f}" .lib).a
	done
	doins "${S}/BaseTools/Scripts"/gcc*-ld-script

	INCLUDE_DEST="/usr/include/edk2"
	INCLUDE_DIR="${S}/MdePkg/Include"
	for f in "" /Uefi /Guid /IndustryStandard /Library /Pi /Protocol; do
		insinto "${INCLUDE_DEST}${f}"
		doins "${INCLUDE_DIR}${f}"/*.h
	done
	insinto "${INCLUDE_DEST}"
	doins "${INCLUDE_DIR}/${ARCH}"/*.h
	for f in /MdeModulePkg /IntelFrameworkPkg; do
		doins -r "${S}/${f}/Include"/*
	done

	dobin "${S}/BaseTools/Source/C/bin/GenFw"

	if use doc; then
		dohtml -r "${S}/doc"/*
	fi

	if use examples; then
		EX_REBUILD_DIR="${S}/${P}-exemples"
		for f in "${S}/MdeModulePkg/Application"/*; do
			EX_NAME=$(basename "${f}")
			mkdir -p "${EX_REBUILD_DIR}/${EX_NAME}"
			EX_BUILD_DIR="${BUILD_DIR}/MdeModulePkg/Application"
			EX_BUILD_DIR="${EX_BUILD_DIR}/${EX_NAME}/${EX_NAME}"
			find "${f}" -name '*.h' -exec mv '{}' \
				"${EX_REBUILD_DIR}/${EX_NAME}" \;
			find "${f}" -name '*.c' -exec mv '{}' \
				"${EX_REBUILD_DIR}/${EX_NAME}" \;
			createMakefile "${EX_REBUILD_DIR}/${EX_NAME}/Makefile" \
				"${EX_NAME}" "${EX_BUILD_DIR}/GNUmakefile"
			mv "${EX_BUILD_DIR}/DEBUG"/AutoGen.* "${EX_REBUILD_DIR}/${EX_NAME}"
			tar -C "${EX_REBUILD_DIR}" -cf "${EX_REBUILD_DIR}/${EX_NAME}.tar" \
				"${EX_NAME}" || die "Failed to create ${EX_NAME} example file"
		done
		docinto "examples"
		dodoc "${EX_REBUILD_DIR}"/*.tar
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
# 1 - Path of the file to create.
# 2 - Name of the module.
# 3 - Path of the generated GNUmakefile
createMakefile() {
	cat >${1} <<EOF
EXEC=${2}.efi
SRC=\$(wildcard *.c)
OBJ=\$(SRC:.c=.o)
INC_DIR=/usr/include/edk2
LIB_DIR=/usr/lib64/${PF}
STATIC_LIBRARY_FILES =  \\
EOF

	perl -ne 'if( m/^STATIC_LIBRARY_FILES\s*=/ ){ $static=1; }elsif( $static ){ if( m!^\s*\$\(BIN_DIR\).*/([^/]*)\.lib! ){ print "\t\"-l${1}\" \\\n" }else{ $static=0; }}' >>${1} <${3}

	cat >>${1} <<EOF

EFI_LDS=\$(LIB_DIR)/gcc4.4-ld-script

EOF
	grep -e '^MODULE_TYPE\s*=' ${3} >>${1}
	grep -e '^IMAGE_ENTRY_POINT\s*=' ${3} >>${1}
	echo >>${1}
	grep -e '^CP\s*=' ${3} >>${1}
	grep -e '^RM\s*=' ${3} >>${1}
	grep -e '^CC\s*=' ${3} >>${1}
	grep -e '^DLINK\s*=' ${3} >>${1}
	grep -e '^OBJCOPY\s*=' ${3} >>${1}
	grep -e '^GENFW\s*=' ${3} >>${1}
	cat >>${1} <<EOF

CC_FLAGS=-g -fshort-wchar -fno-strict-aliasing -Wall -Werror -Wno-array-bounds \
-ffunction-sections -fdata-sections -c -include AutoGen.h -I\$(INC_DIR) \
-DSTRING_ARRAY_NAME=${2}Strings -m64 -fno-stack-protector \
"-DEFIAPI=__attribute__((ms_abi))" -DNO_BUILTIN_VA_FUNCS -mno-red-zone \
-Wno-address -mcmodel=large -Wno-address -Wno-unused-but-set-variable
DLINK_FLAGS=-nostdlib -n -q --gc-sections --script=\$(EFI_LDS) --entry \
\$(IMAGE_ENTRY_POINT) -u \$(IMAGE_ENTRY_POINT) -melf_x86_64 \
--oformat=elf64-x86-64 -L \$(LIB_DIR)
EOF
	grep -e '^OBJCOPY_FLAGS\s*=' ${3} >>${1}
	grep -e '^GENFW_FLAGS\s*=' ${3} >>${1}
	cat >>${1} <<EOF

all:	\$(EXEC)

%.efi:	\$(OBJ)
	\$(DLINK) -o \$(@:.efi=.dll) \$(DLINK_FLAGS) \\
		--start-group \$(STATIC_LIBRARY_FILES) \$^ --end-group
	\$(OBJCOPY) \$(OBJCOPY_FLAGS) \$(@:.efi=.dll)
	\$(CP) \$(@:.efi=.dll) \$(@:.efi=.debug)
	\$(OBJCOPY) --strip-unneeded -R .eh_frame \$(@:.efi=.dll)
	\$(OBJCOPY) --add-gnu-debuglink=\$(@:.efi=.debug) \$(@:.efi=.dll)
	\$(GENFW) -e \$(MODULE_TYPE) -o \$@ \$(@:.efi=.dll) $(GENFW_FLAGS)
	\$(RM) \$(@:.efi=.dll)

%.o:	%.c
	\$(CC) \$(CC_FLAGS) -o \$@ \$^

clean:
	\$(RM) *.o

mrproper: clean
	\$(RM) \$(EXEC) \$(EXEC:.efi=.debug)

.PHONY: all clean mrproper
EOF
}
