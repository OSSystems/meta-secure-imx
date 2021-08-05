SPL_BINARIES ?= "${SPL_BINARY}"

python __anonymous () {

    if d.getVar('HAB_ENABLE', True):
        d.appendVar("DEPENDS", " cst-native")
}

####################
# common
####################
hex2dec() {
	echo $(printf '%d' $1)
}

dec2hex() {
	echo 0x$(printf '%x' $1)
}

set_bd_path() {
	if [ -n "${UBOOT_CONFIG}" ]; then
		bd=${B}/${config}
	else
		bd=${B}
	fi
}

# $1 ... fit image name
# $2 ... part of fit image
fit_get_off() {
	val=$(fdtget $1 /images/$2 data-position)
	# dec -> hex
	dec2hex $val
}

# $1 .... filename
get_filelen() {
	val=$(wc -c $1 | cut -d " " -f 1)
	# dec -> hex
	dec2hex $val
}

# $1 ... fit image name
# $2 ... part of fit image
fit_get_len() {
	val=$(fdtget $1 /images/$2 data-size)
	dec2hex $val
}

# $1 ... fit image name
# $2 ... part of fit image
fit_get_loadaddr() {
	set -x
	val=$(fdtget $1 /images/$2 load)
	set +x
	# dec -> hex
	dec2hex $val
}

get_atf_loadaddr() {
	if [ ! "${CONFIG_IMX8M}" ];then
		return
	fi

	if [ ! ${bd}/u-boot.itb ];then
		bbnote "u-boot.itb does not exist yet"
		return
	fi

	atf_loadaddr=$(fit_get_loadaddr ${bd}/u-boot.itb "atf")
	bbnote "ATF_LOAD_ADDR ${atf_loadaddr}"
	export ATF_LOAD_ADDR=$atf_loadaddr
}

set_variables() {
	set_bd_path
	# source u-boot config so we can use the config symbols
	# as variables
	source ${bd}/.config

	get_atf_loadaddr
}


####################
# imx6 specific
####################

#
# Emit the CSF File
#
# $1 ... .csf filename
# $2 ... SRK Table Binary
# $3 ... CSF Key File
# $4 ... Image Key File
# $5 ... Blocks Parameter
# $6 ... Image File
# $7 ... CAAM / DCP
csf_emit_file() {
	cat << EOF > ${1}
[Header]
Version = 4.1
Hash Algorithm = sha256
Engine Configuration = 0
Certificate Format = X509
Signature Format = CMS
Engine = ${7}

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
Engine = ${7}
Features = RNG
EOF
}

#
# Assemble csf binary
#
# $1 ... csf filename
# $2 ... binary to sign
# 
csf_assemble() {
	blocks="$(sed -n 's/HAB Blocks:[\t ]\+\(0x[0-9a-f]\+\)[ ]\+\(0x[0-9a-f]\+\)[ ]\+\(0x[0-9a-f]\+\)/\1 \2 \3/p' ${2}.log)"
	csf_emit_file "${1}" "${SRKTAB}" "${CSFK}" "${SIGN_CERT}" "${blocks}" "${2}" CAAM
}

sign_uboot_nofit() {
	for config in ${UBOOT_MACHINE}; do
		cd ${B}/${config}
		if [ -n "${SPL_BINARY}" ]; then
			csf_assemble ${SPL_BINARY}.csf ${SPL_BINARY}
			cst --o ${SPL_BINARY}.csf --i ${SPL_BINARY}.csf
			cat ${SPL_BINARY} ${SPL_BINARY}.csf > ${SPL_BINARY}.tmp
			mv ${SPL_BINARY}.tmp ${SPL_BINARY}.${UBOOT_SIGN_SUFFIX}
		fi
		csf_assemble ${UBOOT_BINARY}.csf ${UBOOT_BINARY}
		cst --o ${UBOOT_BINARY}.csf --i ${UBOOT_BINARY}.csf
		cat ${UBOOT_BINARY} ${UBOOT_BINARY}.csf > ${UBOOT_BINARY}.tmp
		mv ${UBOOT_BINARY}.tmp ${UBOOT_BINARY}.${UBOOT_SIGN_SUFFIX}
	done
}

#############################
# u-boot.itb (imx8m) specific
#############################

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
my $output=$ARGV[2];
my $loadaddr = hex(shift);
my $img_size = hex(shift);

my $entry = $loadaddr;
my $ivt_addr = $loadaddr + $img_size;
my $csf_addr = $ivt_addr + 0x20;

open(my $out, '>:raw', $output) or die "Unable to open: $!";
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
# Emit the CSF File for SPL part
#
# !! Attention !!
# For devices prior to HAB v4.4.0, the HAB code locks the Job Ring and DECO
# master ID registers in closed configuration. In case the user specific
# application requires any changes in CAAM MID registers it's necessary to
# add the "Unlock CAAM MID" command in CSF file.
#
# $1 ... filename
# $2 ... SRK Table Binary
# $3 ... CSF Key File
# $4 ... Image Key File
# $5 ... block info
# $6 ... CAAM / DCP
csf_emit_spl_file() {
	cat << EOF > ${1}
[Header]
Version = 4.3
Hash Algorithm = sha256
Engine Configuration = 0
Certificate Format = X509
Signature Format = CMS
Engine = ${6}

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
Blocks = ${5}

[Unlock]
Engine = ${6}
Features = MID
EOF
}

#
# Emit the CSF File for FIT part
#
# $1 ... filename
# $2 ... SRK Table Binary
# $3 ... CSF Key File
# $4 ... Image Key File
# $5 ... block data
# $6 ... CAAM / DCP
csf_emit_fit_file() {
	cat << EOF > ${1}
[Header]
Version = 4.3
Hash Algorithm = sha256
Engine = ${6}
Engine Configuration = 0
Certificate Format = X509
Signature Format = CMS

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
Blocks = ${5}
EOF
}

# $1 ... fit image name
# $2 ... part of fit image
create_block_line() {
	if [ $2 == "uboot" ];then
		addr=$CONFIG_SYS_TEXT_BASE
	fi
	if [ $2 == "fdt" ];then
		ublen=$(fit_get_len $1 uboot)
		ublen=$(hex2dec $ublen)
		# addr = textbase + ublen
		basedec=$(hex2dec $CONFIG_SYS_TEXT_BASE)
		addr=$(expr $basedec + $ublen)
		addr=$(dec2hex $addr)
	fi
	if [ $2 == "atf" ];then
		get_atf_loadaddr
		addr=$atf_loadaddr
	fi
	off=$(fit_get_off $1 $2)
	len=$(fit_get_len $1 $2)
	bbnote "block $2 ${addr} ${off} ${len} $1"
	res=$(echo "${addr} ${off} ${len} \"$1\"")
}

calc_fit_addr() {
	# TEXT_BASE - (FIT_EXTERNAL_OFFSET + sizeof(mkimage header) + 0x200)
	basedec=$(hex2dec $CONFIG_SYS_TEXT_BASE)
	extoff=$(hex2dec $CONFIG_FIT_EXTERNAL_OFFSET)
	mkimghdrsz=64
	off=512

	fit_addr=$(expr $basedec - $extoff - $mkimghdrsz - $off)
	fit_addr=$(dec2hex $fit_addr)
}

# $1 ... fit image name
create_block() {
	calc_fit_addr
	fit_off=0x0
	fit_len=$(fdtdump $fn 2>/dev/null | grep totalsize | cut -d "x" -f 2 | cut -d " " -f 1)
	# align to 0x1000
	fit_len_aligned="$(perl -w ${bd}/get_align_size.pl ${fit_len})"
	# add ivt header length 0x20
	fit_len_aligned_ivt=$(expr $fit_len_aligned + 32)
	fit_len_aligned_ivt=$(dec2hex $fit_len_aligned_ivt)
	bbnote "block fit ${fit_addr} ${fit_off} ${fit_len_aligned_ivt}"
	echo "${fit_addr} ${fit_off} ${fit_len_aligned_ivt} \"$1\", \\" > ${bd}/block

	create_block_line $1 uboot
	echo "$res, \\" >> ${bd}/block
	create_block_line $1 fdt
	echo "$res, \\" >> ${bd}/block
	create_block_line $1 atf
	echo "$res" >> ${bd}/block
}

# $1 ... CONFIG_SPL_TEXT_BASE
# $2 ... imageoffset
# $3 ... filename
# $4 ... imgfile
# $5 ... buildpath
sign_spl() {
	bbnote "sign spl ${1} ${2} ${3} ${4} ${5}"
	bbnote "creat spl csf file: ${bd}/csf_spl.txt"
	fn=$5/$3.signed
	cp $5/$3 $fn
	# startaddr: startaddr = textbase - 0x40 (size of mkimage header)
	basedec=$(hex2dec $1)
	addr=$(expr $basedec - 64)
	addr=$(dec2hex $addr)
	# len = len von u-boot-spl-ddr.bin
	len=$(get_filelen $5/$4)
	bbnote "block spl ${addr} $2 ${len} ${fn}"
	blocks="$addr $2 $len \"${fn}\""
	csf_emit_spl_file "$5/csf_spl_$3.txt" "${SRKTAB}" "${CSFK}" "${SIGN_CERT}" "${blocks}" CAAM
	# create signed data
	cst -i $5/csf_spl_$3.txt -o $5/csf_spl_$3.bin
	# cst off in IVT header
	# read cstoff from file (offset 0x18 4 bytes)
	pos=$(hex2dec $2)
	pos=$(expr $pos + 24)
	cstoff=$(od -xL -j $pos -N 4 $fn | sed -n '2 p' | xargs)
	pos=$(hex2dec $2)
	off=$(expr $cstoff - $basedec + $pos + 64)
	dd if=$5/csf_spl_$3.bin of=$fn seek=$off bs=1 conv=notrunc
}

sign_all_spl() {
	for bin in ${SPL_BINARIES}; do
		off=0x0
		case "${bin}" in
			*qspi*)
				off=0x1000
			;;
		esac
		sign_spl $CONFIG_SPL_TEXT_BASE $off $bin u-boot-spl-ddr.bin ${bd}
	done
}

sign_uboot_binman() {
	for config in ${UBOOT_MACHINE}; do
		set_variables
		sign_all_spl

		# create helper script for aligning address
		get_align_size_emit_file ${bd}/get_align_size.pl

		# FIT
		fn=${bd}/u-boot.itb.signed
		bbnote "signing $fn"
		cp ${bd}/u-boot.itb $fn
		create_block ${fn}
		blocks=$(cat ${bd}/block)
		bbnote "creat spl csf file: ${bd}/csf_fit.txt"

		# one more problem:
		# U-Boot build with SPL_FIT_GENERATOR disabled
		# does not contain IVT Header, so create it here.
		genivt_emit_file ${bd}/imx6-genIVT.pl
		aligned_off="$(perl -w ${bd}/get_align_size.pl ${fit_len})"
		perl -w ${bd}/imx6-genIVT.pl $fit_addr `printf "0x%x" ${aligned_off}` ${bd}/gen.ivt.bin
		bbnote "write IVT header ${bd}/gen.ivt.bin to $fn @ $aligned_off"
		dd if=${bd}/gen.ivt.bin of=$fn seek=$aligned_off bs=1 conv=notrunc conv=fsync

		# create signed data
		csf_emit_fit_file "${bd}/csf_fit.txt" "${SRKTAB}" "${CSFK}" "${SIGN_CERT}" "${blocks}" CAAM
		cst -i ${bd}/csf_fit.txt -o ${bd}/csf_fit.bin
		# insert into image
		#
		# CSF_FIT_OFFSET = 0x1000, see:
		# -> https://elixir.bootlin.com/u-boot/latest/source/arch/arm/mach-imx/spl.c#L325
		# IVT offset is @ ALIGN(fdt_totalsize(fit), 0x1000);
		# so copy csf data to IVT_OFFSET + IVT_HEADER(=x020)
		# align address to 0x1000
		off=$(expr $aligned_off + 32)
		bbnote "write csf data ${bd}/csf_fit.bin to $fn @ $off"
		dd if=${bd}/csf_fit.bin of=$fn seek=$off bs=1 conv=notrunc conv=fsync
	done
}

######################
# common entry points
######################

sign_uboot_common() {
	set_variables

	# detect if we have to sign u-boot.itb image, which contains
	# all infos we need for signing in image itself.
	# Yet only IMX8M supported.
	if [ ${CONFIG_IMX8M} == "y" ];then
		if [ ! "${CONFIG_USE_SPL_FIT_GENERATOR}" ];then
			sign_uboot_binman
		else
			bberror "CONFIG_IMX8M and CONFIG_USE_SPL_FIT_GENERATOR set. Do convert to unset CONFIG_USE_SPL_FIT_GENERATOR"
		fi
	else
		sign_uboot_nofit
	fi
}

do_sign_uboot() {

	if [ "${HAB_ENABLE}" == "1" ];then
		sign_uboot_common
	else
		bbwarn "HAB boot not enabled."
	fi
}

deploy_nofit() {
        for config in ${UBOOT_MACHINE}; do
            i=$(expr $i + 1);
            for type in ${UBOOT_CONFIG}; do
                j=$(expr $j + 1);
                if [ $j -eq $i ]
                then
		    install ${B}/${config}/${SPL_BINARY}.${UBOOT_SIGN_SUFFIX} ${DEPLOYDIR}/${SPL_BINARY}-${type}.${UBOOT_SIGN_SUFFIX}
		    install ${B}/${config}/${UBOOT_BINARY}.${UBOOT_SIGN_SUFFIX} ${DEPLOYDIR}/${UBOOT_BINARY}-${type}.${UBOOT_SIGN_SUFFIX}
                fi
            done
            unset  j
        done
        unset  i
}

deploy_fit() {
	if [ -n "${UBOOT_CONFIG}" ];then
		bbwarn "do_deploy with UBOOT_CONFIG not implemented yet, please add."
	else
		install -D -m 644 ${bd}/${UBOOT_BINARY}.${UBOOT_SIGN_SUFFIX} ${DEPLOYDIR}/${UBOOT_BINARY}.${UBOOT_SIGN_SUFFIX}
		if [ -n "${SPL_BINARY}" ]; then
			bbnote "install ${B}/${SPL_BINARY}.${UBOOT_SIGN_SUFFIX} ${DEPLOYDIR}/${SPL_IMAGE}.${UBOOT_SIGN_SUFFIX}"
			install -m 644 ${B}/${SPL_BINARY}.${UBOOT_SIGN_SUFFIX} ${DEPLOYDIR}/${SPL_IMAGE}.${UBOOT_SIGN_SUFFIX}
			rm -f ${DEPLOYDIR}/${SPL_BINARYNAME}.${UBOOT_SIGN_SUFFIX} ${DEPLOYDIR}/${SPL_SYMLINK}.${UBOOT_SIGN_SUFFIX}
			ln -sf ${SPL_IMAGE}.${UBOOT_SIGN_SUFFIX} ${DEPLOYDIR}/${SPL_BINARYNAME}.${UBOOT_SIGN_SUFFIX}
			ln -sf ${SPL_IMAGE}.${UBOOT_SIGN_SUFFIX} ${DEPLOYDIR}/${SPL_SYMLINK}.${UBOOT_SIGN_SUFFIX}
		fi
	fi
}

do_deploy_append() {

	if [ "${HAB_ENABLE}" == "1" ];then
		set_variables

		# detect if we have to sign u-boot.itb image, which contains
		# all infos we need for signing in image itself.
		# Yet only IMX8M supported.
		if [ ${CONFIG_IMX8M} == "y" ];then
			if [ ! "${CONFIG_USE_SPL_FIT_GENERATOR}" ];then
				deploy_fit
			fi
		else
			deploy_nofit
		fi
	else
		bbwarn "HAB boot not enabled."
	fi
}

addtask sign_uboot before do_install after do_compile

# do_sign_uboot must also run before do_deploy
python () {
    d.appendVarFlag('do_deploy', 'depends', 'virtual/bootloader:do_sign_uboot')
}
