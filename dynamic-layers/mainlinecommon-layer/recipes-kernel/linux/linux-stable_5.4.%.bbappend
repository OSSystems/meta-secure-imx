FILESEXTRAPATHS_append := "${THISDIR}/linux-5.4:"

require linux-crypto-imx.inc

SRC_URI_append = " \
  file://encryption.cfg \
"
