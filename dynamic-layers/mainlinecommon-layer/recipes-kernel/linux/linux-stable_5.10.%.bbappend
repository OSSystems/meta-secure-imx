FILESEXTRAPATHS_append := "${THISDIR}/linux-5.10:"

require linux-crypto-imx.inc

SRC_URI_append = " \
  file://0013-caam_keyblob.c-fix-from-Richard.patch \
  file://encryption-caam.cfg \
"
