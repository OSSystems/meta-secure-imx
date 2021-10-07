SUMMARY = "basic initramfs image init script"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COREBASE}/meta/COPYING.MIT;md5=3da9cfbcb788c80a0384361b4de20420"

SRC_URI = "file://initramfs-init.sh \
	   file://functions_factory \
"

PACKAGES = "${PN} ${PN}-factory"

RDEPENDS_${PN}_append = "busybox util-linux-mount util-linux-findfs \
			 util-linux-uuidd cryptsetup keyutils"

S = "${WORKDIR}"

do_install() {
	install -d ${D}${base_sbindir}
	install -m 0755 ${WORKDIR}/initramfs-init.sh ${D}${base_sbindir}/init

	install -d ${D}${sysconfdir}
	install -m 0755 ${WORKDIR}/functions_factory ${D}${sysconfdir}
}

do_install_append() {
	install -d ${D}/dev
	mknod -m 622 ${D}/dev/console c 5 1
}

inherit allarch

FILES_${PN} = "/dev ${base_sbindir}/init"
FILES_${PN}-factory = "${sysconfdir}/functions_factory"
