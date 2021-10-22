SUMMARY = "Factory FIT image"
DESCRIPTION = "Factory FIT"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

# name of the recipe, which creates the rescue rootfs
RESCUE_NAME = "crypt-image-initramfs-factory"
RESCUE_NAME_FULL = "${RESCUE_NAME}-${MACHINE}.cpio.gz"

require image-fit.inc
