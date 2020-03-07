DESCRIPTION = "Code Signing Tool for NXP's High Assurance Boot with i.MX processors."
AUTHOR = "NXP"
HOMEPAGE = "http://www.nxp.com"
LICENSE = "CLOSED"
LIC_FILES_CHKSUM = "file://Release_Notes.txt;md5=b7e1d61ce9f055fc55549aa1ca498c83"

SRC_URI = "file://cst-${PV}.tar.xz"
SRC_URI[md5sum] = "75fd6c6a273565b4fdb0c0a8e450dd66"
SRC_URI[sha256sum] = "3c4b6d79e8f131b1d21cdb51198d7a334ccc22acb5cf134773f94a697c334eb9"

inherit native

S = "${WORKDIR}/cst-${PV}"

do_patch[noexec] = "1"
do_configure[noexec] = "1"

do_compile() {

	cd code/back_end/src
	${CC} -o cst_encrypt -I ../hdr -L ../../../linux64/lib *.c -lfrontend -lcrypto
	cp cst_encrypt ${S}${SRCDIR}/bin/
}

do_install() {

  install -d ${D}${bindir}
  install -m 0755 ${S}${SRCDIR}/bin/cst ${D}${bindir}
  install -m 0755 ${S}${SRCDIR}/bin/cst_encrypt ${D}${bindir}
  install -m 0755 ${S}${SRCDIR}/bin/srktool ${D}${bindir}
  install -m 0755 ${S}${SRCDIR}/bin/x5092wtls ${D}${bindir}
}

COMPATIBLE_HOST = "(i686|x86_64).*-linux"
SRCDIR_x86-64 = "/linux64"
SRCDIR_i686 = "/linux32"
