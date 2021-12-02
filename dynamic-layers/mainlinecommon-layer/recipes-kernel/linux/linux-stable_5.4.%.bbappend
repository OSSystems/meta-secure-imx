FILESEXTRAPATHS_append := "${THISDIR}/linux-5.4:"

require linux-crypto-imx.inc

SRC_URI_append = " \
  file://encryption.cfg \
  file://0001-ARM-dts-imx6ull-add-rng.patch \
  file://0002-hwrng-imx-rngc-improve-dependencies.patch \
  file://0003-hwrng-imx-rngc-enable-driver-for-i.MX6.patch \
"
