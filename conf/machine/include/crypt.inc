# data volume settings
DATA_VOL ?= "/opt/data"
OFS_DIR ?= "${DATA_VOL}/overlayfs"

SIGN_KEY ?= "${SECURE_BASE}/conf/keys/fs_prime256v1_key.pem"
SIGN_KEY_PUB ?= "${SECURE_BASE}/conf/keys/fs_prime256v1_pub_key.pem"

ENC_KEY_RAW ?= "fdf6842566d47e47d6874da561fec433"

INITRAMFS_IMAGE ?= "crypt-image-initramfs"

IMAGE_FSTYPES = "squashfs-lz4.crypt ext4.crypt ext4.gz.crypt"
IMAGE_CLASSES += "crypt-fs"
