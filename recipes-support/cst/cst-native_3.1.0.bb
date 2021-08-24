# This version is recommended for imx6 SoCs

require cst-native.inc

SRC_URI = "file://cst-${PV}.tgz;subdir=${S}"
SRC_URI[md5sum] = "89a2d6c05253c4de9a1bf9d5710bb7ae"

SRCDIR_x86-64 = "release/linux64"
SRCDIR_i686 = "release/linux32"
