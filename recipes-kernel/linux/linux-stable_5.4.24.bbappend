FILESEXTRAPATHS_prepend := "${THISDIR}/${PN}-${PV}:"

SRC_URI += " \
	file://0001-KEYS-add-symmetric-key-type.patch \
	file://0002-KEYS-add-symmetric-key-test-module.patch \
	file://0003-KEYS-add-CAAM-based-symmetric-key-subtype.patch \
	file://0004-dm-crypt-Add-a-global-keyring-for-symmetric-keys.patch \
	file://0005-camm_key-Disable-debug-print.patch \
	file://0006-fscrypt-Add-support-for-key-types-other-than-logon.patch \
	file://0007-fscrypt-Enable-key-lookup-on-custom-keyring.patch \
	file://0008-ubifs-Add-mount-option-support-for-global-keyring.patch \
	file://0009-ubifs-allow-usage-of-symmetric-key-type-for-UBIFS-en.patch \
	file://0010-ubifs-Fix-build-for-CONFIG_UBIFS_FS_ENCRYPTION-n.patch \
	file://0011-arm-dts-Enable-mxs-dcp-by-default.patch \
	file://0012-crypto-mxs-dcp-Implement-reference-keys.patch \
	file://0013-KEYS-add-DCP-based-symmetric-key-subtype.patch \
	file://encryption.cfg \
"
