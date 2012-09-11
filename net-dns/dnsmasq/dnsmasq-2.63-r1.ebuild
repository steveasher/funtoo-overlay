# Distributed under the terms of the GNU General Public License v2

EAPI=4

inherit eutils toolchain-funcs flag-o-matic user systemd

DESCRIPTION="Small forwarding DNS server"
HOMEPAGE="http://www.thekelleys.org.uk/dnsmasq/"
SRC_URI="http://www.thekelleys.org.uk/dnsmasq/${P}.tar.xz"

LICENSE="|| ( GPL-2 GPL-3 )"
SLOT="0"
KEYWORDS="*"
IUSE="conntrack dbus +dhcp idn ipv6 lua nls script tftp"
DM_LINGUAS="de es fi fr id it no pl pt_BR ro"
for dm_lingua in ${DM_LINGUAS}; do
	IUSE+=" linguas_${dm_lingua}"
done

RDEPEND="dbus? ( sys-apps/dbus )
	idn? ( net-dns/libidn )
	lua? ( dev-lang/lua )
	conntrack? ( net-libs/libnetfilter_conntrack )
	nls? (
		sys-devel/gettext
		net-dns/libidn
	)"

DEPEND="${RDEPEND}
	virtual/pkgconfig
	app-arch/xz-utils"

REQUIRED_USE="lua? ( script )"

use_have() {
	local NO_ONLY=""
	if [ $1 == '-n' ]; then
		NO_ONLY=1
		shift
	fi

	local UWORD=${2:-$1}
	UWORD=${UWORD^^*}

	if ! use ${1}; then
		echo " -DNO_${UWORD}"
	elif [ -z "${NO_ONLY}" ]; then
		echo " -DHAVE_${UWORD}"
	fi
}

pkg_setup() {
	enewgroup dnsmasq
	enewuser dnsmasq -1 -1 /dev/null dnsmasq
}

src_prepare() {
	# dnsmasq on FreeBSD wants the config file in a silly location, this fixes
	epatch "${FILESDIR}/${PN}-2.47-fbsd-config.patch"
	sed -i -r 's:lua5.[0-9]+:lua:' Makefile
}

src_configure() {
	COPTS="$(use_have conntrack)"
	COPTS+="$(use_have dbus)"
	COPTS+="$(use_have -n dhcp)"
	COPTS+="$(use_have idn)"
	COPTS+="$(use_have -n ipv6)"
	COPTS+="$(use_have lua luascript)"
	COPTS+="$(use_have -n script)"
	COPTS+="$(use_have -n tftp)"
	COPTS+="$(use ipv6 && use dhcp || echo " -DNO_DHCP6")"
}

src_compile() {
	emake \
		PREFIX=/usr \
		CC="$(tc-getCC)" \
		CFLAGS="${CFLAGS}" \
		LDFLAGS="${LDFLAGS}" \
		COPTS="${COPTS}" \
		all$(use nls && echo "-i18n")
}

src_install() {
	emake \
		PREFIX=/usr \
		MANDIR=/usr/share/man \
		DESTDIR="${D}" \
		install$(use nls && echo "-i18n")

	local lingua
	for lingua in ${DM_LINGUAS}; do
		use linguas_${lingua} || rm -rf "${D}"/usr/share/locale/${lingua}
	done
	rmdir --ignore-fail-on-non-empty "${D}"/usr/share/locale/

	dodoc CHANGELOG CHANGELOG.archive FAQ
	dodoc -r logo

	dodoc CHANGELOG FAQ
	dohtml *.html

	newinitd "${FILESDIR}"/dnsmasq-init-r2 dnsmasq
	newconfd "${FILESDIR}"/dnsmasq.confd-r2 dnsmasq

	insinto /etc
	newins dnsmasq.conf.example dnsmasq.conf

	if use dbus ; then
		insinto /etc/dbus-1/system.d
		doins dbus/dnsmasq.conf
	fi

	systemd_dounit "${FILESDIR}"/dnsmasq.service
}
