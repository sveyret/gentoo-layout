# Copyright 1999-2017 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2

EAPI=6
PYTHON_COMPAT=( python2_7 )

inherit eutils gnome2-utils

DESCRIPTION="Crypto-currency software to manage libre currency"
HOMEPAGE="https://duniter.org/"

SRC_URI="https://github.com/duniter/${PN}/archive/v${PV}.tar.gz -> ${P}.tar.gz"

LICENSE="AGPL-3"
SLOT="0"
KEYWORDS="~amd64"
IUSE="+desktop +web"
REQUIRED_USE="desktop? ( web )"

RDEPEND="
	>=net-libs/nodejs-6.9.4[npm,ssl]
"
DEPEND="
	${RDEPEND}
	${PYTHON_DEPS}
	sys-apps/yarn
"

ADDON_VERSION=48
NW_VERSION=0.17.6

nw_copy() {
	[[ -z ${1} ]] && die
	cp lib/binding/Release/node-webkit-v${NW_VERSION}-linux-x64/${1}.node \
		lib/binding/Release/node-v${ADDON_VERSION}-linux-x64/${1}.node || die
}

nw_copy_node() {
	[[ -z ${1} ]] && die
	cp lib/binding/node-webkit-v${NW_VERSION}-linux-x64/node_${1}.node \
		lib/binding/node-v${ADDON_VERSION}-linux-x64/node_${1}.node || die
}

nw_compile() {
	[[ -z ${1} ]] && die
	cd ${1} || die
	node-pre-gyp --runtime=node-webkit --target=${NW_VERSION} configure || die
	node-pre-gyp --runtime=node-webkit --target=${NW_VERSION} build || die
	[[ -z ${2} ]] || ${2} ${1}
	cd ..
}

src_compile() {
	yarn || die

	if use web; then
		yarn add duniter-ui@1.4.x || die
		sed -i "s/duniter\//..\/..\/..\/..\//g" node_modules/duniter-ui/server/controller/webmin.js || die
	fi

	npm prune --production || die

	# Specific modules that are not needed in a release
	rm -rf node_modules/materialize-css
	rm -rf node_modules/duniter-ui/app
	rm -rf node_modules/duniter-ui/vendor
	rm -rf node_modules/scryptb/node_modules/node-pre-gyp
	rm -rf node_modules/naclb/node_modules/node-pre-gyp
	rm -rf node_modules/wotb/node_modules/node-pre-gyp
	rm -rf node_modules/sqlite3/build

	# Generate desktop
	if use desktop; then
		PATH=$(npm bin):${PATH}
		npm install node-pre-gyp || die
		npm install nw-gyp || die
		npm install nw@${NW_VERSION} || die

		# Webkit compilation
		cd node_modules || die
		nw_compile wotb nw_copy
		nw_compile naclb nw_copy
		nw_compile scryptb nw_copy
		nw_compile sqlite3 nw_copy_node
		cd heapdump || die
		nw-gyp --target=${NW_VERSION} configure || die
		nw-gyp --target=${NW_VERSION} build || die
		cd ..
		cd ..

		# Unused binaries
		rm -rf node_modules/sqlite3/build
		npm uninstall node-pre-gyp || die
		npm uninstall nw-gyp || die

		# Update package.json
		sed -i "s/\"main\": \"index.js\",/\"main\": \"index.html\",/" package.json

		# Update path to icon
		sed -i "s:^\\(Icon\\s*=\\s*\\)/.*/\\([^/]*\\)$:\\1\\2:" release/arch/debian/package/usr/share/applications/duniter.desktop

		# Create launch script
		cat <<-EOF >duniter-desktop.sh
		DUNITER_DIR="${EPREFIX%/}/opt/${PN}"
		cd "\$DUNITER_DIR"
		"\$DUNITER_DIR/node_modules/.bin/nw" "\$@"
		EOF
	fi

	# Cleanup
	rm -f node_modules/.bin/{esparse,esvalidate,strip-json-comments}
	rm -f node_modules/q-io/node_modules/.bin/mime
	rm -f node_modules/duniter-ui/node_modules/.bin/node-pre-gyp
	rm -f node_modules/naclb/node_modules/tar-pack/node_modules/.bin/rimraf
	rm -f node_modules/sqlite3/node_modules/.bin/node-pre-gyp
	if ! use desktop; then
		rm -f node_modules/wotb/node_modules/.bin/node-pre-gyp
		rm -f node_modules/scryptb/node_modules/.bin/node-pre-gyp
		rm -f node_modules/naclb/node_modules/.bin/node-pre-gyp
	fi

	# Recreate script
	cat <<-EOF >duniter.sh
	DUNITER_DIR="${EPREFIX%/}/opt/${PN}"
	cd "\$DUNITER_DIR"
	node "\$DUNITER_DIR/bin/duniter" "\$@"
	EOF
}

src_install() {
	local target=${EPREFIX%/}/opt/${PN}
	local subelem
	dodir ${target}

	insinto ${target}
	for subelem in package.json tsconfig.json index.* server.* appveyor.yml yarn.lock; do
		doins ${subelem}
	done
	if use desktop; then
		doins gui/index.html
		doicon -s scalable gui/duniter.png
	fi
	for subelem in app bin doc images node_modules node_modules/.bin; do
		insinto ${target}/${subelem}
		doins -r ${subelem}/*
	done

	for subelem in $(realpath --relative-to=${PWD} $(readlink -f node_modules/.bin/*)) node_modules/nw/nwjs/nw; do
		if [[ -f ${subelem} ]]; then
			rm ${D%/}${target}/${subelem} || die
			exeinto ${target}/$(dirname ${subelem})
			doexe ${subelem}
		fi
	done

	exeinto ${target}
	doexe duniter.sh
	dosym ${target}/duniter.sh ${EPREFIX%/}/usr/bin/duniter

	if use desktop; then
		doexe duniter-desktop.sh
		dosym ${target}/duniter-desktop.sh ${EPREFIX%/}/usr/bin/duniter-desktop
		domenu release/arch/debian/package/usr/share/applications/duniter.desktop
	fi
}

pkg_postinst() {
	use desktop && gnome2_icon_cache_update
}

pkg_postrm() {
	use desktop && gnome2_icon_cache_update
}
