# Copyright 2020 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=7
PYTHON_COMPAT=( python2_7 )

inherit desktop python-r1 systemd xdg-utils

DESCRIPTION="Crypto-currency software to manage libre currency"
HOMEPAGE="https://duniter.org/"

SRC_URI="https://git.duniter.org/nodes/typescript/${PN}/repository/v${PV}/archive.tar.gz -> ${P}.tar.gz"

LICENSE="AGPL-3"
SLOT="0"
KEYWORDS="~amd64 ~arm"
IUSE="desktop +gui debug"
REQUIRED_USE="desktop? ( gui )"

COMMON_DEPEND="
	desktop? ( =net-libs/nodejs-10*[npm,ssl] )
	!desktop? ( net-libs/nodejs[npm,ssl] )
"
BDEPEND="
	${COMMON_DEPEND}
	${PYTHON_DEPS}
	dev-lang/rust
"
RDEPEND="
	${COMMON_DEPEND}
	!desktop? ( acct-group/duniter )
	!desktop? ( acct-user/duniter )
	!net-p2p/duniter-desktop-bin
"

RESTRICT="primaryuri"

src_unpack() {
	unpack ${A}
	mv "${WORKDIR}/${PN}-v${PV}-"* "${S}"
}

src_compile() {
	python_setup

	# Set appropriate make target
	local makeTarget=server
	if use desktop; then
		makeTarget=desktop
	elif use gui; then
		makeTarget=server-gui
	fi

	# Add debug if requested
	local addDebug=N
	use debug && addDebug=Y

	# Create package
	emake -C release ADD_DEBUG=${addDebug} ${makeTarget}

	# Correctionns
	if use desktop; then
		# Update path to icon
		sed -i "s:^\\(Icon\\s*=\\s*\\)/.*/\\([^/]*\\)\\.[^.]*$:\\1\\2:" \
			work/extra/desktop/usr/share/applications/duniter.desktop || die
		# Do not use default script file
		rm work/duniter.sh
	else
		# Change default script file
		cat <<-EOF >work/duniter.sh || die
			DUNITER_DIR="${EPREFIX%/}/opt/${PN}"
			cd "\$DUNITER_DIR"
			node "\$DUNITER_DIR/bin/duniter" "\$@"
		EOF
	fi
}

src_install() {
	pushd work >/dev/null || die

	local target="${EPREFIX%/}/opt/${PN}"
	local subelem
	dodir "${target}"

	# Install commands
	exeinto "${target}"
	if use desktop; then
		doexe duniter-desktop
		rm -f duniter-desktop
		dosym "${target}/duniter-desktop" "${EPREFIX%/}/usr/bin/duniter-desktop"
		doicon -s scalable duniter.png
		domenu extra/desktop/usr/share/applications/duniter.desktop
	else
		doexe duniter.sh
		rm -f duniter.sh
		dosym "${target}/duniter.sh" "${EPREFIX%/}/usr/bin/duniter"
		newinitd extra/openrc/duniter.initd duniter
		newconfd extra/openrc/duniter.confd duniter
		systemd_dounit extra/systemd/duniter.service

		# Install bash completion
		dodir /etc/bash_completion.d
		insinto /etc/bash_completion.d
		doins extra/completion/duniter_completion.bash
	fi

	# Intall executables
	for subelem in $(realpath --relative-to="${PWD}" $(readlink -f node_modules/.bin/*)); do
		if [[ -f "${subelem}" ]]; then
			exeinto "${target}/"$(dirname "${subelem}")
			doexe "${subelem}"
			rm -f "${subelem}"
		fi
	done

	# Install other files
	insinto "${target}"
	doins -r .

	popd >/dev/null || die
}

pkg_postinst() {
	if use desktop; then
		xdg_icon_cache_update
		xdg_desktop_database_update
	else
		elog "To start Duniter at boot, add Duniter to the default runlevel:"
		elog "  rc-update add duniter default"
		elog "or for systemd:"
		elog "  systemctl enable duniter.service"
	fi
}

pkg_postrm() {
	if use desktop; then
		xdg_icon_cache_update
		xdg_desktop_database_update
	fi
}
