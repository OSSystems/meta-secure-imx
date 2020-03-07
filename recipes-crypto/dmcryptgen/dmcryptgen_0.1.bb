DESCRIPTION = "Encrypt a diskimage for dmcrypt offline"
LICENSE = "GPLv2"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/GPL-2.0;md5=801f80980d171dd6425610833a22dbe6"

SRC_URI = "file://dmcrypt_gen.c"

S = "${WORKDIR}"

DEPENDS = "openssl pkgconfig-native"
BBCLASSEXTEND += "native"
INSANE_SKIP_${PN} += "ldflags"

do_compile() {
	SSLFLAGS="`pkg-config --cflags openssl`"
	LDFLAGS="`pkg-config --libs openssl`"
	${CC} dmcrypt_gen.c ${SSLFLAGS} -o dmcrypt_gen ${LDFLAGS?}
}

do_install() {
	install -d ${D}${bindir}
	install -m 0755 dmcrypt_gen ${D}${bindir}
}
