#################################################################################
#
# Sign filesystem
#
# Author: Embexus Embedded Systems Solutions 
#         ayoub.zaki@embexus.com
# Contributor: Bosch Thermotechnik GmbH
#              Matthias Winker
#
# This class takes a complete file system binary (preferably SquashFS)
#    Pads it to a 1 MiB multiple
#    Attaches a "Magic" marker to it to mark the start of the signature area
#    Calculates the digest of the file system container, incl. padding and magic
#    Creates a signature of that digest using OpenSSL tools
#    And attaches the signature to the final, signed file system container
#
# +------------+  0x0                     -
# |            |                          |
# |            |                          |
# |            |                          |
# |            |                          |
# | File       |                          |
# | System     |                          |
# .            |                          |
# .            |                           > PAYLOAD to be signed      ----+
# .            |                          |                                |
# |            |                          |                                |
# |            |                          |                                |
# +------------+                          |                                |
# |            |                          |                                |
# | Fill Data  |                          |                                |
# |            |                          |                                |
# +------------+ MAGIC_OFFSET(MB Aligned) -                                |
# | Magic 4k   |                                                           |
# +------------+ MAGIC_OFFSET + MAGIC_LEN                                  |
# |            |                                                           |
# | Signature  | <---------------------------------------------------------+
# | 4k         |
# +------------+

inherit image_types

CONVERSIONTYPES += " signed"
CONVERSION_DEPENDS_signed = "openssl-native coreutils-native"

DEPENDS += "openssl-native coreutils-native"

INPUT="${IMAGE_NAME}${IMAGE_NAME_SUFFIX}.${type}"
WORK="${INPUT}.tmp"
DIGEST="${INPUT}.digest"
OUTPUT="${IMAGE_NAME}${IMAGE_NAME_SUFFIX}.${type}.signed"

#1MB Alignement
MB="$(expr 1024 \* 1024)"

# Magic marker such that the initramfs is able to find the signature
MAGIC="DENX_MGC"
MAGIC_SIZE="4096"
align_data_size() {
    FILE_SZ="$(stat -Lc%s "${1}")"
    FILE_MB_SZ="$(expr $FILE_SZ \/ ${MB})"
    ALIGN_SZ="$(expr $(expr $FILE_MB_SZ + 1) \* ${MB})"
    truncate -s "${ALIGN_SZ}" ${1}
    MAGIC_OFFSET="${ALIGN_SZ}"
    export MAGIC_OFFSET=${MAGIC_OFFSET}
}

calc_digest() {
    openssl dgst -sha256 -binary -out ${DIGEST} ${1}
}

set_sig_area() {
    # Clear/reserve space for magic/signature, otherwise garbage on disk may be interpreted as part of the signature
    dd if=/dev/zero of=${1} seek=${MAGIC_OFFSET} bs=8K count=1 conv=notrunc oflag=seek_bytes  > /dev/null 2>&1
}

set_magic() {
    echo ${MAGIC} | dd  of=${1} seek=$(expr ${MAGIC_OFFSET} / 4096) bs=4k count=1 conv=notrunc  > /dev/null 2>&1
}

attach_signature() {
    openssl pkeyutl -sign -in ${DIGEST} -inkey ${SIGN_KEY} -out ${1}.sig -pkeyopt digest:sha256
    base64 ${1}.sig > ${1}.b64
    dd if=${1}.b64 of=${1} seek=$(expr $(expr ${MAGIC_OFFSET} + ${MAGIC_SIZE}) / 4096) bs=4k count=1 conv=notrunc  > /dev/null 2>&1
    mv ${1} ${1}.signed
}

CONVERSION_CMD_signed() {
    cp ${INPUT} ${WORK}
    align_data_size ${WORK}
    calc_digest ${WORK}
    set_sig_area ${WORK}
    set_magic ${WORK}
    attach_signature ${WORK}
    mv ${WORK}.signed ${OUTPUT}
    rm -f ${WORK}*
}
