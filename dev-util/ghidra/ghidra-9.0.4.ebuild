# Copyright 1999-2019 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=7

DESCRIPTION="A software reverse engineering framework"
HOMEPAGE="https://www.nsa.gov/ghidra"
SRC_URI="https://github.com/NationalSecurityAgency/${PN}/archive/Ghidra_${PV}_build.tar.gz
	https://github.com/pxb1988/dex2jar/releases/download/2.0/dex-tools-2.0.zip
	https://storage.googleapis.com/google-code-archive-downloads/v2/code.google.com/android4me/AXMLPrinter2.jar
	https://sourceforge.net/projects/catacombae/files/HFSExplorer/0.21/hfsexplorer-0_21-bin.zip
	mirror://sourceforge/yajsw/yajsw/yajsw-stable-12.12.zip
	https://dev.pentoo.ch/~blshkv/distfiles/${P}-gradle-dependencies.tar.gz"
# run: pentoo/scripts/gradle_dependencies.py from "${S}" directory to generate dependencies
# tar cvzf ./ghidra-9.0.4-gradle-dependencies.tar.gz -C /var/tmp/portage/dev-util/ghidra-9.0.4/work ghidra-Ghidra_9.0.4_build/dependencies/

LICENSE="Apache-2.0"
SLOT="0"
KEYWORDS="~amd64 ~x86"
IUSE=""

RDEPEND=">=virtual/jre-1.8"
DEPEND="${RDEPEND}
	>=virtual/jdk-11
	dev-java/gradle-bin:5.2.1
	sys-devel/bison
	dev-java/jflex
	app-arch/unzip"

S="${WORKDIR}/ghidra-Ghidra_${PV}_build"

src_unpack() {
	#https://github.com/NationalSecurityAgency/ghidra/blob/05ad1aa9f3a28721467ae288be6769f226f7147d/DevGuide.md
	unpack ${A}
	mkdir -p "${S}/.gradle/flatRepo" || die "(1) mkdir failed"
	cd "${S}/.gradle"

	unpack dex-tools-2.0.zip
	cp dex2jar-2.0/lib/dex-*.jar ./flatRepo || die "(3) cp failed"

	cp "${DISTDIR}/AXMLPrinter2.jar" ./flatRepo  || die "(4) cp failed"

	unpack hfsexplorer-0_21-bin.zip
	cp lib/*.jar ./flatRepo            || die "(5) cp failed"

	mkdir -p "${WORKDIR}"/ghidra.bin/Ghidra/Features/GhidraServer/ || die "(6) mkdir failed"
	cp "${DISTDIR}"/yajsw-stable-12.12.zip "${WORKDIR}"/ghidra.bin/Ghidra/Features/GhidraServer/ || die "(7) cp failed"
	cd "${S}"
}

src_prepare() {
	sed -i 's|gradle.gradleVersion != "5.0"|gradle.gradleVersion <= "5.0"|g' build.gradle || die "(9) sed failed"
	mkdir -p ".gradle/init.d"                       || die "(10) mkdir failed"
	cp "${FILESDIR}"/repos.gradle .gradle/init.d    || die "(11) cp failed"
	sed -i "s|S_DIR|${S}|g" .gradle/init.d/repos.gradle || die "(12) sed failed"
	#remove build date so we can unpack dist.zip later
	sed -i "s|_\${rootProject.BUILD_DATE_SHORT}||g" gradleScripts/distribution.gradle || die "(13) sed failed"

	if [[ -z "$(eselect java-vm show system | grep '11')"  ]]; then
		eerror "JDK 11 is not installed or not selected. Please run the following:"
		eerror "eselect java-vm set system <jdk-11>"
		die
	fi

	eapply_user
}

src_compile() {
	export _JAVA_OPTIONS="$_JAVA_OPTIONS -Duser.home=$HOME"

	GRADLE="gradle-5.2.1 --gradle-user-home .gradle --console rich --no-daemon"
	GRADLE="${GRADLE} --offline"

	unset TERM
	${GRADLE} yajswDevUnpack -x check -x test || die
	${GRADLE} buildGhidra -x check -x test || die
}

src_install() {
	#it is easier to unpack existing archive
	dodir /usr/share
	unzip build/dist/ghidra_9.0.x-DEV_PUBLIC_linux64.zip -d "${ED}"/usr/share/ || die "unable to unpack dist zip"
	mv "${ED}"/usr/share//ghidra_9.0.x-DEV "${ED}"/usr/share/ghidra || die "mv failed"

	#fixme: add doc flag
	rm -r  "${ED}"/usr/share/ghidra/docs/ || die "rm failed"
	dosym "${EPREFIX}"/usr/share/ghidra/ghidraRun /usr/bin/ghidra
}
