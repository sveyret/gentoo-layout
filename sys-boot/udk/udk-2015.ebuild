# Copyright 1999-2016 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Id$

EAPI=6

PYTHON_COMPAT=( python2_7 )
PYTHON_REQ_USE="sqlite"

inherit flag-o-matic multiprocessing python-single-r1 toolchain-funcs versionator

DESCRIPTION="Tianocore UEFI Development kit"
HOMEPAGE="http://www.tianocore.org/edk2/"
MY_V="${PN^^}$(get_version_component_range 1)"
SRC_URI="https://github.com/tianocore/${PN}/releases/download/${MY_V}/${MY_V}.Complete.MyWorkSpace.zip"

LICENSE="BSD"
SLOT="0"
KEYWORDS="~amd64 ~x86"
IUSE="doc examples"

DEPEND="app-arch/unzip
	dev-lang/nasm
	${PYTHON_DEPS}"
REQUIRED_USE="${PYTHON_REQUIRED_USE}"

S="${WORKDIR}/MyWorkSpace"

pkg_setup() {
	UNAME_ARCH=$(uname -m | sed -e 's:i[3456789]86:IA32:')
	if [[ ${UNAME_ARCH} == "x86_64" ]] || [[ ${UNAME_ARCH} == "amd64" ]] ; then
		export ARCH=X64
	else
		export ARCH=${UNAME_ARCH}
	fi

	# We will create a custom toolchain with user defined settings
	export TOOLCHAIN_TAG="CUSTOM"
}

src_unpack() {
	unpack ${A}
	unpack "${WORKDIR}/${MY_V}.MyWorkSpace.zip"

	pushd "${S}" || die
	unpack "${WORKDIR}/BaseTools(Unix).tar"

	local doc_name
	if use doc; then
		mkdir -p "${S}/doc" || die
		pushd "${S}/doc" >/dev/null || die
		for f in "${WORKDIR}/Documents/"*" Document.zip"; do
			doc_name=$(echo ${f} | sed -e 's:^.*/([^/]*) Document.zip$:\1:')
			if [[ -f "${WORKDIR}/Documents/${doc_name} Document.zip" ]]; then
				unpack "${WORKDIR}/Documents/${doc_name} Document.zip"
				mv "${S}/doc/html" "${S}/doc/${doc_name}" || die
			fi
		done
		popd >/dev/null || die
	fi

	popd >/dev/null || die
}

src_configure() {
	python_setup 'python2.7'

	# Compile of Base Tools is required for further setting up the environment
	# Base tools does not like parallel make
	local cflags_save=${CFLAGS}
	append-cflags $(test-flags-CC -MD) $(test-flags-CC -fshort-wchar)
	append-cflags $(test-flags-CC -fno-strict-aliasing)
	append-cflags $(test-flags-CC -nostdlib) $(test-flags-CC -c)
	sed -e "s:^\(CFLAGS\s*=\).*$:\1 ${CFLAGS}:" \
		-i "${S}/BaseTools/Source/C/Makefiles/header.makefile" \
		|| die "Failed to update makefile header"
	local make_flags=(
		CC="$(tc-getCC)"
		CXX="$(tc-getCXX)"
		AS="$(tc-getAS)"
		AR="$(tc-getAR)"
		LD="$(tc-getLD)"
	)
	emake "${make_flags[@]}" -j1 -C BaseTools
	. edksetup.sh BaseTools

	# Update flags in UDK parameter files
	CFLAGS=${cflags_save}
	append-cflags $(test-flags-CC -fshort-wchar)
	append-cflags $(test-flags-CC -fno-strict-aliasing) $(test-flags-CC -c)
	append-cflags $(test-flags-CC -ffunction-sections)
	append-cflags $(test-flags-CC -fdata-sections)
	append-cflags $(test-flags-CC -fno-stack-protector)
	append-cflags $(test-flags-CC -fno-asynchronous-unwind-tables)
	if [[ "${ARCH}" == "X64" ]]; then
		append-cflags $(test-flags-CC -m64) $(test-flags-CC -mno-red-zone)
		append-cflags $(test-flags-CC -mcmodel=large)
	else
		append-cflags $(test-flags-CC -m32) $(test-flags-CC -malign-double)
	fi
	append-ldflags -nostdlib -n -q --gc-sections
	sed -e "s:^\(ACTIVE_PLATFORM\s*=\).*$:\1 MdeModulePkg/MdeModulePkg.dsc:" \
		-e "s:^\(TARGET\s*=\).*$:\1 RELEASE:" \
		-e "s:^\(TARGET_ARCH\s*=\).*$:\1 ${ARCH}:" \
		-e "s:^\(TOOL_CHAIN_TAG\s*=\).*$:\1 ${TOOLCHAIN_TAG}:" \
		-e "s:^\(MAX_CONCURRENT_THREAD_NUMBER\s*=\).*$:\1 $(makeopts_jobs):" \
		-i "${S}/Conf/target.txt" || die "Failed to configure target file"
	cat >>${S}/Conf/tools_def.txt <<EOF

*_CUSTOM_*_*_FAMILY          = GCC
*_CUSTOM_*_MAKE_PATH         = make
*_CUSTOM_*_ASL_PATH          = DEF(UNIX_IASL_BIN)
*_CUSTOM_*_OBJCOPY_PATH      = $(tc-getOBJCOPY)
*_CUSTOM_*_CC_PATH           = $(tc-getCC)
*_CUSTOM_*_SLINK_PATH        = $(tc-getAR)
*_CUSTOM_*_DLINK_PATH        = $(tc-getLD)
*_CUSTOM_*_ASLDLINK_PATH     = $(tc-getLD)
*_CUSTOM_*_ASM_PATH          = $(tc-getCC)
*_CUSTOM_*_PP_PATH           = $(tc-getCC)
*_CUSTOM_*_VFRPP_PATH        = $(tc-getCC)
*_CUSTOM_*_ASLCC_PATH        = $(tc-getCC)
*_CUSTOM_*_ASLPP_PATH        = $(tc-getCC)
*_CUSTOM_*_RC_PATH           = $(tc-getOBJCOPY)
*_CUSTOM_*_PP_FLAGS          = DEF(GCC_PP_FLAGS)
*_CUSTOM_*_ASLPP_FLAGS       = DEF(GCC_ASLPP_FLAGS)
*_CUSTOM_*_ASLCC_FLAGS       = DEF(GCC_ASLCC_FLAGS)
*_CUSTOM_*_VFRPP_FLAGS       = DEF(GCC_VFRPP_FLAGS)
*_CUSTOM_*_APP_FLAGS         =
*_CUSTOM_*_ASL_FLAGS         = DEF(IASL_FLAGS)
*_CUSTOM_*_ASL_OUTFLAGS      = DEF(IASL_OUTFLAGS)
*_CUSTOM_*_OBJCOPY_FLAGS     = 
*_CUSTOM_IA32_ASLCC_FLAGS    = DEF(GCC_ASLCC_FLAGS) -m32
*_CUSTOM_IA32_ASM_FLAGS      = DEF(GCC_ASM_FLAGS) -m32 -march=i386
*_CUSTOM_IA32_CC_FLAGS       = ${CFLAGS} -include AutoGen.h -DSTRING_ARRAY_NAME=\$(BASE_NAME)Strings -D EFI32
*_CUSTOM_IA32_ASLDLINK_FLAGS = ${LDFLAGS} -z common-page-size=0x40 --entry ReferenceAcpiTable -u ReferenceAcpiTable -m elf_i386
*_CUSTOM_IA32_DLINK_FLAGS    = ${LDFLAGS} -z common-page-size=0x40 --entry \$(IMAGE_ENTRY_POINT) -u \$(IMAGE_ENTRY_POINT) -Map \$(DEST_DIR_DEBUG)/\$(BASE_NAME).map -m elf_i386 --oformat=elf32-i386
*_CUSTOM_IA32_DLINK2_FLAGS   = DEF(GCC_DLINK2_FLAGS_COMMON) --defsym=PECOFF_HEADER_SIZE=0x220
*_CUSTOM_IA32_RC_FLAGS       = DEF(GCC_IA32_RC_FLAGS)
*_CUSTOM_IA32_NASM_FLAGS     = -f elf32
*_CUSTOM_X64_ASLCC_FLAGS     = DEF(GCC_ASLCC_FLAGS) -m64
*_CUSTOM_X64_ASM_FLAGS       = DEF(GCC_ASM_FLAGS) -m64
*_CUSTOM_X64_CC_FLAGS        = ${CFLAGS} -include AutoGen.h -DSTRING_ARRAY_NAME=\$(BASE_NAME)Strings "-DEFIAPI=__attribute__((ms_abi))" -DNO_BUILTIN_VA_FUNCS
*_CUSTOM_X64_ASLDLINK_FLAGS  = ${LDFLAGS} -z common-page-size=0x40 --entry ReferenceAcpiTable -u ReferenceAcpiTable -m elf_x86_64
*_CUSTOM_X64_DLINK_FLAGS     = ${LDFLAGS} -z common-page-size=0x40 --entry \$(IMAGE_ENTRY_POINT) -u \$(IMAGE_ENTRY_POINT) -Map \$(DEST_DIR_DEBUG)/\$(BASE_NAME).map -m elf_x86_64 --oformat=elf64-x86-64
*_CUSTOM_X64_DLINK2_FLAGS    = DEF(GCC_DLINK2_FLAGS_COMMON) --defsym=PECOFF_HEADER_SIZE=0x228
*_CUSTOM_X64_RC_FLAGS        = DEF(GCC_X64_RC_FLAGS)
*_CUSTOM_X64_NASM_FLAGS      = -f elf64
EOF
}

src_compile() {
	local build_target
	if use examples; then
		build_target=all
	else
		build_target=libraries
	fi

	build ${build_target} || die "Failed to compile environment"
}

src_install() {
	local build_dir="${S}/Build/MdeModule/RELEASE_${TOOLCHAIN_TAG}/${ARCH}"

	for f in "${build_dir}"/*/Library/*/*/OUTPUT/*.lib; do
		newlib.a "${f}" lib$(basename "${f}" .lib).a
	done
	dolib "${S}/BaseTools/Scripts/GccBase.lds"

	local include_dest="/usr/include/${PN}"
	for f in "" /Guid /IndustryStandard /Library /Pi /Ppi /Protocol /Uefi; do
		insinto "${include_dest}${f}"
		doins "${S}/MdePkg/Include${f}"/*.h
	done
	insinto "${include_dest}"
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

	local ex_rebuild_dir
	local ex_name
	local ex_build_dir
	if use examples; then
		ex_rebuild_dir="${S}/${P}-exemples"
		for f in "${S}/MdeModulePkg/Application"/*; do
			ex_name=$(basename "${f}")
			ebegin "Preparing ${ex_name} example"
			mkdir -p "${ex_rebuild_dir}/${ex_name}" || die
			ex_build_dir="${build_dir}/MdeModulePkg/Application"
			ex_build_dir="${ex_build_dir}/${ex_name}/${ex_name}"

			copySourceFiles "${f}" "${ex_rebuild_dir}/${ex_name}"
			copySourceFiles "${ex_build_dir}/DEBUG" "${ex_rebuild_dir}/${ex_name}"
			createMakefile "${ex_rebuild_dir}/${ex_name}/Makefile" \
				"${ex_name}" "${ex_build_dir}/GNUmakefile" || die

			tar -C "${ex_rebuild_dir}" -cf "${ex_rebuild_dir}/${ex_name}.tar" \
				"${ex_name}" || die

			eend $? "Failed to create example file"
		done
		docinto "examples"
		dodoc "${ex_rebuild_dir}"/*.tar
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

##
# Parameters :
# 1 - Path where to search for source files.
# 2 - Path where source files must be copied.
copySourceFiles() {
	while read -d '' -r filename; do
		DEST_FILE="${2}${filename#${1}}"
		mkdir -p $(dirname "${DEST_FILE}") || die
		mv "${filename}" "${DEST_FILE}" || die
	done < <(find "${1}" -name '*.h' -print0 -o -name '*.c' -print0)
}

# This looks like it should instead have a template Makefile shipped with the
# ebuild which is then copied and sed'd to meet requirements.

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
