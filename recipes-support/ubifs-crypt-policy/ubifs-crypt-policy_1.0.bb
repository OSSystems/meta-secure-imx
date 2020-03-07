FILESEXTRAPATHS_prepend := "${THISDIR}/${PN}:"

SRC_URI = " \
	file://ubifs_crypt_policy.c \
	file://LICENSE \
	file://Makefile \
	"

LIC_FILES_CHKSUM = "file://LICENSE;md5=9dac6785a3c334e42556037c8b864b7f"

LICENSE = "MIT"

FILES_${PN} = "${bindir}"

S = "${WORKDIR}"

INSANE_SKIP_${PN} += "ldflags"

do_compile() {
    oe_runmake all
}

do_install_append() {
    install -d ${D}${bindir}
    install -m 0755 ubifs_crypt_policy ${D}${bindir}
}
