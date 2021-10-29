CFLAGS_append = " -DDANGEROUS_COMMANDS_ENABLED"

# This switch enables commands which are permanent.
# For example to set mmcblk1boot1 partition to RO
# one needs to call:
#
# mmc writeprotect boot set [-p] /dev/mmcblk1 1

# The [-p] switch is for permanent RO. Without it
# the eMMC is RO only till reboot.
