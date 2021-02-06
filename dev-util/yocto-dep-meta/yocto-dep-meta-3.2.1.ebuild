# Copyright 1999-2021 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=7

DESCRIPTION="Meta package managing Yocto dependencies"
HOMEPAGE="https://www.yoctoproject.org/"
LICENSE="metapackage"
SLOT="0"

KEYWORDS="~amd64"

RDEPEND="
	app-admin/chrpath
	app-arch/cpio
	app-arch/unzip
	app-arch/xz-utils
	dev-lang/python
	dev-python/GitPython
	dev-python/jinja
	dev-python/pip
	dev-python/pexpect
	dev-python/subunit
	dev-util/diffstat
	dev-vcs/git
	net-misc/socat
	net-misc/wget
	sys-apps/debianutils
	sys-apps/file[-seccomp]
	sys-apps/gawk
	sys-apps/texinfo
	x11-terms/xterm
"
DEPEND=""
BDEPEND=""
S=${WORKDIR}
