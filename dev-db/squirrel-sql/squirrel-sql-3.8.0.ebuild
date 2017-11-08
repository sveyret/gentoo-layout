# Copyright 1999-2017 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2

EAPI=6

inherit versionator java-pkg-2

DESCRIPTION="Universal SQL Client"
HOMEPAGE="http://www.squirrelsql.org/"
SRC_URI="mirror://sourceforge/project/${PN}/1-stable/${PV}-plainzip/squirrelsql-${PV}-standard.zip"
RESTRICT="primaryuri"

LICENSE="LGPL-3"
SLOT="0"
KEYWORDS="~amd64 ~x86"
IUSE="mssql mysql postgres sybase"

DEPEND=">=virtual/jdk-1.6:*"
RDEPEND="
	${DEPEND}
	dev-java/log4j
	postgres? ( dev-java/jdbc-postgresql )
	mysql? ( dev-java/jdbc-mysql )
	mssql? ( dev-java/jdbc-mssqlserver )
	sybase? ( dev-java/jtds )
"

S="${WORKDIR}/squirrelsql-${PV}-standard"

src_install() {
	local squirrel_dir="${EROOT}usr/share/${PN}"
	insinto "${squirrel_dir}"

	doins -r icons log4j.properties plugins

	java-pkg_dojar ${PN}.jar
	for jar in lib/*.jar; do
		java-pkg_dojar "${jar}"
		java-pkg_regjar "${jar}"
	done

	for backend in ${IUSE}; do
		use "${backend}" && {
			local jb
			if [ "${backend}" == "postgres" ]; then
				jb="postgresql"
			elif [ "${backend}" == "mssql" ]; then
				jb="mssqlserver"
			elif [ "${backend}" == "sybase" ]; then
				jb="jtds"
			else
				jb="${backend}"
			fi
			for jar in $(find /usr/share/jdbc-${jb}/lib/ -name '*.jar' 2>/dev/null); do
				java-pkg_regjar "${jar}"
			done
		}
	done

	java-pkg_dolauncher "${PN}" --main net.sourceforge.squirrel_sql.client.Main --java_args "-splash:${squirrel_dir}/icons/splash.jpg" \
		--pkg_args "--log-config-file ${squirrel_dir}/log4j.properties --squirrel-home ${squirrel_dir}" --pwd "${squirrel_dir}"
	make_desktop_entry "${PN}" "SQuirreL SQL" "${squirrel_dir}/icons/acorn.png" "Development"
}
