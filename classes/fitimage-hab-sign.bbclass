python __anonymous () {

    if d.getVar('HAB_ENABLE', True):
        d.appendVar("DEPENDS", " cst-native perl-native")
}

attach_ivt() {

	IMAGE_SIZE="`wc -c < ${1}`"
	get_align_size_emit_file get_align_size.pl
	genivt_emit_file imx6-genIVT.pl
	ALIGNED_SIZE="$(perl -w get_align_size.pl ${IMAGE_SIZE})"
	objcopy -I binary -O binary --pad-to ${ALIGNED_SIZE} --gap-fill=0x00 ${1} ${1}-pad
	perl -w imx6-genIVT.pl ${FITLOADADDR} `printf "0x%x" ${ALIGNED_SIZE}`
	cat ${1}-pad ivt.bin > ${1}-ivt
	rm -f ${1}-pad
}

get_align_size_emit_file() {

	cat << 'EOF' > ${1}
use strict;
my $image_size = $ARGV[0];
my $aligned_size = (($image_size + 0x1000 - 1)  & ~ (0x1000 - 1));
print  "$aligned_size\n";
EOF
}

genivt_emit_file() {

	cat << 'EOF' > ${1}
use strict;
my $loadaddr = hex(shift);
my $img_size = hex(shift);

my $entry = $loadaddr + 0x1000;
my $ivt_addr = $loadaddr + $img_size;
my $csf_addr = $ivt_addr + 0x20;

open(my $out, '>:raw', 'ivt.bin') or die "Unable to open: $!";
print $out pack("V", 0x412000D1); # IVT Header
print $out pack("V", $entry); # Jump Location
print $out pack("V", 0x0); # Reserved
print $out pack("V", 0x0); # DCD pointer
print $out pack("V", 0x0); # Boot Data
print $out pack("V", $ivt_addr); # Self Pointer
print $out pack("V", $csf_addr); # CSF Pointer
print $out pack("V", 0x0); # Reserved
close($out);
EOF
}

#
# Emit the CSF File
#
# $1 ... .csf filename
# $2 ... SRK Table Binary
# $3 ... CSF Key File
# $4 ... Image Key File
# $5 ... Blocks Parameter
# $6 ... Image File
csf_emit_file() {
	cat << EOF > ${1}
[Header]
Version = 4.1
Hash Algorithm = sha256
Engine Configuration = 0
Certificate Format = X509
Signature Format = CMS
Engine = CAAM

[Install SRK]
File = "${2}"
Source index = 0

[Install CSFK]
File = "${3}"

[Authenticate CSF]

[Install Key]
Verification index = 0
Target Index = 2
File= "${4}"

[Authenticate Data]
Verification index = 2
Blocks = ${5} "${6}"

[Unlock]
Engine = CAAM
Features = RNG
EOF
}

#
# Assemble csf binary
#
# $1 ... .csf filename
# $2 ...  signeable binary filename
# 
csf_assemble() {

	rm -f ${1}

	RAM_AUTH_AREA_START=${FITLOADADDR}
	IMG_SIGN_AREA_START=0x0000
	IMG_SIGN_AREA_SIZE=$(printf "0x%x" `wc -c < ${2}`)
	blocks="${RAM_AUTH_AREA_START}   ${IMG_SIGN_AREA_START}   ${IMG_SIGN_AREA_SIZE}"

	csf_emit_file ${1} ${SRKTAB} ${CSFK} ${SIGN_CERT} "${blocks}" ${2}
}

kernel_do_deploy_append() {

	cd ${B}/arch/${ARCH}/boot
	if [ -n ${HAB_ENABLE} ];then
		if [ -n "${INITRAMFS_IMAGE}" ] && [ -f "fitImage-${INITRAMFS_IMAGE}" ]; then
			FITIMAGE="fitImage-${INITRAMFS_IMAGE}"
			FITLOADADDR=`mkimage -l ${FITIMAGE} | awk 'NR<14 {print $0}' | grep "Load Address:" | cut -d':' -f 2`
			attach_ivt ${FITIMAGE}
			csf_assemble command_sequence_${FITIMAGE}-ivt.csf ${FITIMAGE}-ivt
			echo "cst --o ${FITIMAGE}-ivt.csf --i command_sequence_${FITIMAGE}-ivt.csf"
			cst --o ${FITIMAGE}-ivt.csf --i command_sequence_${FITIMAGE}-ivt.csf
			cat ${FITIMAGE}-ivt ${FITIMAGE}-ivt.csf > ${FITIMAGE}-ivt.tmp
			cp ${FITIMAGE}-ivt.tmp ${FITIMAGE}-ivt.${KERNEL_SIGN_SUFFIX}
			rm -f ${FITIMAGE}-ivt.tmp ${FITIMAGE}-ivt.csf ${FITIMAGE}-ivt
			install ${FITIMAGE}-ivt.${KERNEL_SIGN_SUFFIX} ${DEPLOYDIR}/fitImage-${INITRAMFS_IMAGE}-${MACHINE}.bin.${KERNEL_SIGN_SUFFIX}
		else
			bbwarn "${B}/arch/${ARCH}/boot/fitImage-${INITRAMFS_IMAGE} not found!"	
		fi
	else
		bbwarn "HAB_ENABLE not set!"
	fi
}
