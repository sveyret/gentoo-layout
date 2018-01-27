# Copyright 1999-2018 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2

EAPI=6
PYTHON_COMPAT=( python2_7 )

inherit eutils gnome2-utils python-r1 systemd user

DESCRIPTION="Crypto-currency software to manage libre currency"
HOMEPAGE="https://duniter.org/"

SRC_URI="https://git.duniter.org/nodes/typescript/${PN}/repository/v${PV}/archive.tar.gz -> ${P}.tar.gz"

LICENSE="AGPL-3"
SLOT="0"
KEYWORDS="~amd64"
IUSE="+desktop +gui"
REQUIRED_USE="desktop? ( gui )"

RDEPEND="
	>=net-libs/nodejs-8.9.1[npm,ssl]
"
DEPEND="
	${RDEPEND}
	${PYTHON_DEPS}
"

NW_VERSION=0.24.4
DUNITER_UI_VERSION=1.6.x

nw_copy() {
	[[ -z ${1} ]] && die
	cp lib/binding/Release/node-webkit-v${NW_VERSION}-linux-x64/${1}.node \
		lib/binding/Release/node-v*-linux-x64/${1}.node || die
}

nw_copy_node() {
	[[ -z ${1} ]] && die
	cp lib/binding/node-webkit-v${NW_VERSION}-linux-x64/node_${1}.node \
		lib/binding/node-v*-linux-x64/node_${1}.node || die
}

nw_compile() {
	[[ -z ${1} ]] && die
	cd ${1} || die
	node-pre-gyp --runtime=node-webkit --target=${NW_VERSION} configure || die
	node-pre-gyp --runtime=node-webkit --target=${NW_VERSION} build || die
	[[ -z ${2} ]] || ${2} ${1}
	cd ..
}

src_unpack() {
	unpack ${A}
	mv "${WORKDIR}/${PN}-v${PV}-"* "${S}"
}

src_compile() {
	python_setup
	npm install || die

	if use gui; then
		npm install duniter-ui@${DUNITER_UI_VERSION} || die
	fi

	npm prune --production || die

	# Generate desktop
	if use desktop; then
		PATH=$(npm bin):${PATH}
		npm install node-pre-gyp || die
		npm install nw-gyp || die
		npm install nw@${NW_VERSION} || die

		# FIX: bug of nw.js, we need to patch first.
		cd node_modules/wotb || die
		node-pre-gyp --runtime=node-webkit --target=${NW_VERSION} configure \
		  || echo "This failure is expected"
		cd ../..
		cp release/arch/linux/0.24.4_common.gypi ${HOME}/.nw-gyp/0.24.4/common.gypi || die

		# Webkit compilation
		cd node_modules || die
		nw_compile wotb nw_copy
		nw_compile naclb nw_copy
		nw_compile scryptb nw_copy
		nw_compile sqlite3 nw_copy_node
		cd ..

		# Unused binaries
		rm -rf node_modules/sqlite3/build
		npm uninstall node-pre-gyp || die
		npm uninstall nw-gyp || die

		# Update package.json
		sed -i "s/\"main\": \"index.js\",/\"main\": \"index.html\",/" \
			package.json || die

		# Update path to icon
		sed -i "s:^\\(Icon\\s*=\\s*\\)/.*/\\([^/]*\\)\\.[^.]*$:\\1\\2:" \
			release/extra/desktop/usr/share/applications/duniter.desktop || die
	fi

	# Create launch script
	cat <<-EOF >duniter.sh || die
	DUNITER_DIR="${EPREFIX%/}/usr/lib/${PN}"
	cd "\$DUNITER_DIR"
	EOF
	if use desktop; then
		echo '"$DUNITER_DIR/node_modules/.bin/nw" "$@"' >>duniter.sh || die
	else
		echo 'node "$DUNITER_DIR/bin/duniter" "$@"' >>duniter.sh || die
	fi
}

src_install() {
	local target="${EPREFIX%/}/usr/lib/${PN}"
	local subelem
	dodir "${target}"

	insinto "${target}"
	for subelem in package.json tsconfig.json index.* server.* appveyor.yml yarn.lock; do
		doins ${subelem}
	done
	use desktop && doins gui/{index.html,duniter.png}
	for subelem in app bin doc images node_modules node_modules/.bin; do
		insinto "${target}/"${subelem}
		doins -r ${subelem}/*
	done

	for subelem in $(realpath --relative-to="${PWD}" $(readlink -f node_modules/.bin/*)) node_modules/nw/nwjs/nw; do
		if [[ -f "${subelem}" ]]; then
			rm "${D%/}${target}/${subelem}" || die
			exeinto "${target}/"$(dirname "${subelem}")
			doexe "${subelem}"
		fi
	done

	exeinto "${target}"
	doexe duniter.sh
	if use desktop; then
		dosym "${target}/duniter.sh" "${EPREFIX%/}/usr/bin/duniter-desktop"
		doicon -s scalable gui/duniter.png
		domenu release/extra/desktop/usr/share/applications/duniter.desktop
	else
		dosym "${target}/duniter.sh" "${EPREFIX%/}/usr/bin/duniter"
		newinitd release/extra/openrc/duniter.initd duniter
		newconfd release/extra/openrc/duniter.confd duniter
		systemd_dounit release/extra/systemd/duniter.service
	fi
}

pkg_postinst() {
	if use desktop; then
		gnome2_icon_cache_update
	else
		enewgroup duniter
		enewuser duniter -1 -1 "${EPREFIX%/}/var/lib/duniter" duniter
		elog
		elog "To start Duniter at boot, add Duniter to the default runlevel:"
		elog "  rc-update add duniter default"
		elog "or for systemd:"
		elog "  systemctl enable duniter.service"
	fi
}

pkg_postrm() {
	use desktop && gnome2_icon_cache_update
}
