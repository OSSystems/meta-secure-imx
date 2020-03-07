# bbclass to take care of generating encrypted images for swupdate.

DEPENDS += "openssl-native coreutils-native"
# parameters: $1 = input file, $2 = output file
swu_encrypt_file() {
	input=$1
	output=$2
	key=`cat ${SWU_KEY} | cut -d ' ' -f 1`
	iv=`cat ${SWU_KEY} | cut -d ' ' -f 2`
	salt=`cat ${SWU_KEY} | cut -d ' ' -f 3`
	openssl enc -aes-256-cbc -in ${input} -out ${output} -K ${key} -iv ${iv} -S ${salt}
}

kernel_do_deploy_append() {
	swu_encrypt_file ${DEPLOYDIR}/fitImage-${INITRAMFS_IMAGE}-${MACHINE}.bin.${KERNEL_SIGN_SUFFIX} ${DEPLOYDIR}/fitImage-${INITRAMFS_IMAGE}-${MACHINE}.bin.${KERNEL_SIGN_SUFFIX}.encrypt
}

CONVERSIONTYPES += " encrypt"

CONVERSION_CMD_encrypt(){
	swu_encrypt_file ${IMAGE_NAME}${IMAGE_NAME_SUFFIX}.${type} ${IMAGE_NAME}${IMAGE_NAME_SUFFIX}.${type}.encrypt
}
