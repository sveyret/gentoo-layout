# Copyright 1999-2016 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Id$

EAPI=6

PYTHON_COMPAT=( python2_7 )
PYTHON_REQ_USE="sqlite"

inherit multiprocessing python-single-r1 versionator

DESCRIPTION="Tianocore UEFI Development kit"
HOMEPAGE="http://www.tianocore.org/edk2/"
MY_V="${PN^^}$(get_version_component_range 1)"
SRC_URI="https://github.com/tianocore/${PN}/releases/download/${MY_V}/${MY_V}.Complete.MyWorkSpace.zip"

LICENSE="BSD"
SLOT="0"
KEYWORDS="~amd64 ~x86"
IUSE="-debug doc examples"

DEPEND="app-arch/unzip dev-lang/nasm ${PYTHON_DEPS}"
REQUIRED_USE="${PYTHON_REQUIRED_USE}"

S="${WORKDIR}/MyWorkSpace"

pkg_setup() {
	UNAME_ARCH=$(uname -m | perl -pe 's@i[3456789]86@IA32@' )
	if [[ ${UNAME_ARCH} == "x86_64" ]] || [[ ${UNAME_ARCH} == "amd64" ]] ; then
		export ARCH=X64
	else
		export ARCH=${UNAME_ARCH}
	fi
	use debug && export COMPILE_MODE="DEBUG" || export COMPILE_MODE="RELEASE"
	GCC_VERS=$(gcc --version | head -1 | sed "s/.*)//")
	GCC_VERS=$(get_version_component_range 1-2 ${GCC_VERS})
	GCC_VERS=$(delete_all_version_separators ${GCC_VERS})
	if [[ ${GCC_VERS} -lt 44 ]] || [[ ${GCC_VERS} -gt 49 ]]; then
		export TOOLCHAIN_TAG="ELFGCC"
	else
		export TOOLCHAIN_TAG="GCC${GCC_VERS}"
	fi
}

src_unpack() {
	unpack ${A}
	unpack "${WORKDIR}/${MY_V}.MyWorkSpace.zip"
	pushd "${S}"
	unpack "${WORKDIR}/BaseTools(Unix).tar"
	if use doc; then
		mkdir -p "${S}/doc"
		cd "${S}/doc"
		for f in "${WORKDIR}/Documents/"*" Document.zip"; do
			DOC_NAME=$(echo ${f} | perl -pe 's@^.*/([^/]*) Document.zip$@\1@')
			unpack "${WORKDIR}/Documents/${DOC_NAME} Document.zip"
			mv "${S}/doc/html" "${S}/doc/${DOC_NAME}"
		done
	fi
	popd
}

src_prepare() {
	eapply_user
	python_setup 'python2.7'
	# Base tools does not like parallel make
	emake -j1 -C BaseTools
	. edksetup.sh BaseTools
}

src_configure() {
	perl -i -pe 's@^(ACTIVE_PLATFORM\s*=).*$@\1 MdeModulePkg/MdeModulePkg.dsc@; \
		s/^(TARGET\s*=).*$/\1 '${COMPILE_MODE}'/; \
		s/^(TARGET_ARCH\s*=).*$/\1 '${ARCH}'/; \
		s/^(TOOL_CHAIN_TAG\s*=).*$/\1 '${TOOLCHAIN_TAG}'/; \
		s/^(MAX_CONCURRENT_THREAD_NUMBER\s*=).*$/\1 '$(makeopts_jobs)'/' \
		"${S}/Conf/target.txt" || die "Failed to configure target file"
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
	BUILD_DIR="${S}/Build/MdeModule/${COMPILE_MODE}_${TOOLCHAIN_TAG}/${ARCH}"

	for f in "${BUILD_DIR}"/*/Library/*/*/OUTPUT/*.lib; do
		newlib.a "${f}" lib$(basename "${f}" .lib).a
	done
	dolib "${S}/BaseTools/Scripts/GccBase.lds"

	INCLUDE_DEST="/usr/include/${PN}"
	for f in "" /Guid /IndustryStandard /Library /Pi /Ppi /Protocol /Uefi; do
		insinto "${INCLUDE_DEST}${f}"
		doins "${S}/MdePkg/Include${f}"/*.h
	done
	insinto "${INCLUDE_DEST}"
	doins "${S}/MdePkg/Include/${ARCH}"/*.h
	find "${S}" -name 'BaseTools' -prune -o -name 'MdePkg' -prune -o \
		-name 'CryptoPkg' -prune -o -type d -name Include \
		-exec find {} -maxdepth 0 \; \
		| while read hfile; do
		doins -r "${hfile}"/*
	done

	dobin "${S}/BaseTools/Source/C/bin/GenFw"

	if use doc; then
		docinto "html"
		# Document installation may be very long, so split it and display message
		for f in "${S}"/doc/*; do
			ebegin "Installing documentation for $(basename ${f}), please wait"
			dodoc -r "${f}"
			eend $?
		done
	fi

	if use examples; then
		EX_REBUILD_DIR="${S}/${P}-exemples"
		for f in "${S}/MdeModulePkg/Application"/*; do
			EX_NAME=$(basename "${f}")
			ebegin "Preparing ${EX_NAME} example"
			mkdir -p "${EX_REBUILD_DIR}/${EX_NAME}"
			EX_BUILD_DIR="${BUILD_DIR}/MdeModulePkg/Application"
			EX_BUILD_DIR="${EX_BUILD_DIR}/${EX_NAME}/${EX_NAME}"
			copySourceFiles "${f}" "${EX_REBUILD_DIR}/${EX_NAME}"
			copySourceFiles "${EX_BUILD_DIR}/DEBUG" "${EX_REBUILD_DIR}/${EX_NAME}"
			createMakefile "${EX_REBUILD_DIR}/${EX_NAME}/Makefile" \
				"${EX_NAME}" "${EX_BUILD_DIR}/GNUmakefile"
			tar -C "${EX_REBUILD_DIR}" -cf "${EX_REBUILD_DIR}/${EX_NAME}.tar" \
				"${EX_NAME}"
			eend $? "Failed to create example file"
		done
		docinto "examples"
		dodoc "${EX_REBUILD_DIR}"/*.tar
	fi

# TODO * QA Notice: The following files contain writable and executable sections
# TODO * !WX --- --- usr/lib64/libBaseLib.a:Thunk16.obj
# TODO * !WX --- --- usr/lib64/libBaseLib.a:SwitchStack.obj
# TODO * !WX --- --- usr/lib64/libBaseLib.a:SetJump.obj
# TODO * !WX --- --- usr/lib64/libBaseLib.a:LongJump.obj
# TODO * !WX --- --- usr/lib64/libBaseLib.a:EnableDisableInterrupts.obj
# TODO * !WX --- --- usr/lib64/libBaseLib.a:DisablePaging64.obj
# TODO * !WX --- --- usr/lib64/libBaseLib.a:CpuId.obj
# TODO * !WX --- --- usr/lib64/libBaseLib.a:CpuIdEx.obj
# TODO * !WX --- --- usr/lib64/libBaseLib.a:EnableCache.obj
# TODO * !WX --- --- usr/lib64/libBaseLib.a:DisableCache.obj
# TODO * QA Notice: Package triggers severe warnings which indicate that it
# TODO *            may exhibit random runtime failures.
# TODO * /usr/include/bits/string3.h:90:70: warning: call to void* __builtin___memset_chk(void*, int, long unsigned int, long unsigned int) will always overflow destination buffer
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
# 1 - Path where to search for source files.
# 2 - Path where source files must be copied.
copySourceFiles() {
	while read -d '' -r filename; do
		DEST_FILE="${2}${filename#${1}}"
		mkdir -p $(dirname "${DEST_FILE}")
		mv "${filename}" "${DEST_FILE}"
	done < <(find "${1}" -name '*.h' -print0 -o -name '*.c' -print0)
}

##
# Parameters :
# 1 - Path of the file to create.
# 2 - Name of the module.
# 3 - Path of the generated Makefile.
createMakefile() {
	cat >${1} <<EOF
TOP := \$(abspath \$(dir \$(lastword \$(MAKEFILE_LIST))))
EXEC = ${2}.efi
SRC = \$(shell find \$(TOP) -type f -name '*.c')
OBJ = \$(SRC:.c=.o)
INC_DIR = /usr/include/${PN}
LIB_DIR = /usr/lib
STATIC_LIBRARY_FILES = \\
EOF

	perl -ne \
'if( m/^STATIC_LIBRARY_FILES\s*=/ ) {
	$static=1;
} elsif( $static ) {
	if( m!^\s*\$\(BIN_DIR\).*/([^/]*)\.lib! ) {
		print "\t\"-l${1}\" \\\n"
	} else {
		$static=0;
	}
}' >>${1} <${3}

	cat >>${1} <<EOF

EFI_LDS = \$(LIB_DIR)/GccBase.lds

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
	[[ $ARCH == X64 ]] && PECOFF_HEADER_SIZE='0x228' || PECOFF_HEADER_SIZE='0x220'
	cat >>${1} <<EOF

CC_FLAGS = -g -fshort-wchar -fno-strict-aliasing -Wall -Werror \
-Wno-array-bounds -ffunction-sections -fdata-sections -c -iquote\$(TOP) \
-include AutoGen.h -I\$(INC_DIR) -DSTRING_ARRAY_NAME=${2}Strings -m64 \
-fno-stack-protector "-DEFIAPI=__attribute__((ms_abi))" -DNO_BUILTIN_VA_FUNCS \
-mno-red-zone -Wno-address -mcmodel=large -Wno-address \
-Wno-unused-but-set-variable
DLINK_FLAGS=-nostdlib -n -q --gc-sections --entry \$(IMAGE_ENTRY_POINT) \
-u \$(IMAGE_ENTRY_POINT) -melf_x86_64 --oformat=elf64-x86-64 -L \$(LIB_DIR) \
--script=\$(EFI_LDS) --defsym=PECOFF_HEADER_SIZE=${PECOFF_HEADER_SIZE}
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
	\$(GENFW) -e \$(MODULE_TYPE) -o \$@ \$(@:.efi=.dll) \$(GENFW_FLAGS)
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
