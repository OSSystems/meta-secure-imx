FILESEXTRAPATHS_prepend := "${THISDIR}/files:"
SRC_URI = " \
	file://rescue.its.in \
"

DEPENDS += " \
	dtc-native \
	u-boot-mkimage-native \
       "

do_assemble_fit[depends] += "virtual/kernel:do_deploy"

do_patch[noexec] = "1"
do_configure[noexec] = "1"
do_assemble_fit[nostamp] = "1"
do_package[noexec] = "1"
do_packagedata[noexec] = "1"
deltask package_write_ipk
deltask package_write_deb
deltask package_write_rpm
deltask do_deploy_archives
deltask do_rootfs

S = "${WORKDIR}"
B = "${S}"

ITB_FNAME = "${PN}.itb"

# create fit Image
do_assemble_fit() {
	echo "STAGING_KERNEL_DIR" ${STAGING_KERNEL_DIR}
	echo "STAGING_KERNEL_BUILDDIR" ${STAGING_KERNEL_BUILDDIR}
	echo "KERNEL_SRC_PATH" ${KERNEL_SRC_PATH}
	export DEPLOY_DIR_IMAGE=${DEPLOY_DIR_IMAGE}
	export KERNEL_DEVICETREE=${KERNEL_DEVICETREE}
	export RESCUE_NAME_FULL=${RESCUE_NAME_FULL}
	export RESCUE_RUNNING_VERSION=${RESCUE_RUNNING_VERSION}
	export MACHINE=${MACHINE}
	export TARGET_ARCH=${TARGET_ARCH}
	echo "B" ${B}
	echo "S" ${S}
	echo $DEPLOY_DIR_IMAGE
	echo "FNAME " ${ITB_FNAME}
	cd ${B}
	cp ${B}/rescue.its.in ${B}/rescue.its
	sed -i "s|DEPLOY_DIR_IMAGE|$DEPLOY_DIR_IMAGE|g" rescue.its
	sed -i "s|RESCUE_NAME_FULL|$RESCUE_NAME_FULL|g" rescue.its
	sed -i "s|RESCUE_RUNNING_VERSION|$RESCUE_RUNNING_VERSION|g" rescue.its
	sed -i "s|MACHINE|$MACHINE|g" rescue.its
	sed -i "s|TARGET_ARCH|$TARGET_ARCH|g" rescue.its
	sed -i "s|KERNEL_DEVICETREE|$KERNEL_DEVICETREE|g" rescue.its
	cat rescue.its
	echo "======== create itb file ==========="
	uboot-mkimage -D "-I dts -O dtb -p 0x1000" -f rescue.its ${ITB_FNAME}
		if [ $? -ne 0 ]; then
		echo create FIT image failed
		exit 1
	fi

	install -d ${DEPLOY_DIR_IMAGE}
	install -m 644 ${ITB_FNAME} ${DEPLOY_DIR_IMAGE}/${ITB_FNAME}
}
addtask do_assemble_fit before do_install after do_compile

do_assemble_fit[depends] += "${RESCUE_NAME}:do_image_complete"
