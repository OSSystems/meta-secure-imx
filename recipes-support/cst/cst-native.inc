DESCRIPTION = "Code Signing Tool for NXP's High Assurance Boot with i.MX processors."
AUTHOR = "NXP"
HOMEPAGE = "http://www.nxp.com"
LICENSE = "CLOSED"

INSANE_SKIP_${PN} += " \
 already-stripped \
"

inherit native

S = "${WORKDIR}/cst-${PV}"

do_patch[noexec] = "1"
do_configure[noexec] = "1"
do_compile[noexec] = "1"

do_install() {
  install -d ${D}${bindir}
  install -m 0755 ${S}/${SRCDIR}/bin/cst ${D}${bindir}
  install -m 0755 ${S}/${SRCDIR}/bin/srktool ${D}${bindir}
  install -m 0755 ${S}/${SRCDIR}/bin/hab_log_parser ${D}${bindir}
}

COMPATIBLE_HOST = "(i686|x86_64).*-linux"
SRCDIR_x86-64 = "/linux64"
SRCDIR_i686 = "/linux32"
