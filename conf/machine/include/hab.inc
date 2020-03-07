# HAB Settings
HAB_ENABLE = "1"
HAB_DIR ?= "${SECURE_BASE}/conf/hab"
SRKTAB ?= "${HAB_DIR}/crts/SRK_1_2_3_4_table.bin"
CSFK ?= "${HAB_DIR}/crts/CSF1_1_sha256_secp521r1_v3_usr_crt.pem"
SIGN_CERT ?= "${HAB_DIR}/crts/IMG1_1_sha256_secp521r1_v3_usr_crt.pem"

# u-boot
UBOOT_NAME = "u-boot-ivt"
UBOOT_SIGN_SUFFIX = "signed"
UBOOT_BINARY = "${UBOOT_NAME}.${UBOOT_SUFFIX}"

# kernel
KERNEL_SIGN_SUFFIX = "signed"
KERNEL_CLASSES += "fitimage-hab-sign swupdate-encrypt"
IMAGE_BOOT_FILES = "fitImage-${INITRAMFS_IMAGE}-${MACHINE}.bin.${KERNEL_SIGN_SUFFIX};fitImage"
