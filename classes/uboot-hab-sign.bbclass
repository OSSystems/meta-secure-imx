python __anonymous () {

    if d.getVar('HAB_ENABLE', True):
        d.appendVar("DEPENDS", " cst-native")
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

do_sign_uboot() {

	if [ "${HAB_ENABLE}" == "1" ];then
		sign_uboot_nofit
	else
		bbwarn "HAB boot not enabled."
	fi
}

do_deploy_append() {

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

addtask sign_uboot before do_install after do_compile
