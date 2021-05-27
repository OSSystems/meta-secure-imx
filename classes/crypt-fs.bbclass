# bbclass to take care of generating crypted FS image

inherit image_types

CONVERSIONTYPES += " crypt"
CONVERSION_DEPENDS_crypt = "dmcryptgen-native cryptsetup-native openssl-native coreutils-native"
# parameters: $1 = input file

crypt_file() {
	echo "CRYPTING FILE " $1
	# Add path to native libs so you need not the libs installed
	# on your build host (libssl, libcrypto)
	CP=${RECIPE_SYSROOT_NATIVE}/usr/lib
	export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:${CP}
	input=$1
	key=${ENC_KEY_RAW}
	if [ -z "${key}" ];then
		bbfatal "ENC_KEY_RAW must be set to encrypt the filesystem"
	fi
	bbnote "KEY ${key}"
	dmcrypt_gen ${input} ${key}
}

CONVERSION_CMD_crypt(){
	cp ${IMAGE_NAME}${IMAGE_NAME_SUFFIX}.${type} ${IMAGE_NAME}${IMAGE_NAME_SUFFIX}.${type}.crypt
	crypt_file ${IMAGE_NAME}${IMAGE_NAME_SUFFIX}.${type}.crypt
}
