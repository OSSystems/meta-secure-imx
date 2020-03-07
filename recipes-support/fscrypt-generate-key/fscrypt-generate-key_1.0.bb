SUMMARY = "simple tool which generates key for fscrypt"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://LICENSE;md5=9dac6785a3c334e42556037c8b864b7f"

FILESEXTRAPATHS_prepend := "${THISDIR}/${PN}:"

SRC_URI = " \
	file://fscrypt_generate_key.c \
	file://LICENSE \
	file://Makefile \
	"

FILES_${PN} = "${bindir}"

S = "${WORKDIR}"

INSANE_SKIP_${PN} += "ldflags"

do_compile() {
    oe_runmake all
}

do_install_append() {
    install -d ${D}${bindir}
    install -m 0755 fscrypt_generate_key ${D}${bindir}
}
