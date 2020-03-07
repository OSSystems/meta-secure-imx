#!/bin/sh

PATH=/sbin:/bin:/usr/sbin:/usr/bin

ROOT_MNT="/mnt"
ROOT_DEV=""
ROOT_OPT="-o,ro,noatime,discard,nodelalloc"

# mount/umount
MOUNT="/bin/mount"
UMOUNT="/bin/umount"

# init
INIT="/sbin/init"

mount_pseudo_fs() {
    $MOUNT -t devtmpfs none /dev
    $MOUNT -t tmpfs tmp /tmp
    $MOUNT -t proc proc /proc
    $MOUNT -t sysfs sysfs /sys
}

umount_pseudo_fs() {
    $UMOUNT /dev
    $UMOUNT /tmp
    $UMOUNT /proc
    $UMOUNT /sys
}

parse_cmdline() {
    #Parse kernel cmdline to extract base device path
    CMDLINE="$(cat /proc/cmdline)"
    #echo "Kernel cmdline: $CMDLINE"
    for c in ${CMDLINE}; do
        if [ "${c:0:5}" == "root=" ]; then
            ROOT_DEV="${c:5}"
        fi
    done
}

error_exit() {
    echo "Fatal error!"
    led_set_error
    # wait 5 seconds and reboot
    sleep 5
    reboot -f
}

keyblobpath=/tmp/dmcrypt.blob
storedevice=/sys/class/i2c-dev/i2c-0/device/0-0050/eeprom

# load key blob into $keyblobpath
# check, if key is valid (calculate md5sum and check
# if it is != dc6c58c971715e8043baef058b675eec
# which is the md5sum, if key contains only 0xff)
#
# Currently, if key is invalid, we create the key
# but this must be removed for production initramfs
# as CRYPT_KEY contains the raw key, which never
# should be visible.
create_key_blob() {

    # Load the dcpblob from storage device to $keyblobpath
    # dmcrypt dcp blob @ 1k size = 128 bytes
    dd of=$keyblobpath if=$storedevice bs=128 skip=8 count=1 2> /dev/null

    # check if there is a key
    # currently we check, if there are 0xff only
    # if so we have no key in i2c eeprom
    md5sum $keyblobpath > /tmp/gnlmpf
    grep dc6c58c971715e8043baef058b675eec /tmp/gnlmpf
    if [ $? -ne 0 ];then
        echo "found key, do not create key"
	rm /tmp/gnlmpf
	return
    fi
    rm /tmp/gnlmpf

    # Create dmcrypt blob for rootfs
    keyid=$(keyctl show -x | grep dm_crypt | cut -f 1 -d " ")
    keyctl add symmetric "myplainkey" "dcp load_plain ${CRYPT_KEY}" $keyid

    # get ID for reading out dcp blob
    key_id=$(keyctl show -x | grep myplainkey | cut -f 1 -d " ")
    keyctl pipe $key_id > $keyblobpath

    #store the blob now in storage device
    dd if=$keyblobpath of=$storedevice bs=1k seek=1 2> /dev/null
}

encrypt_rootfs () {
    echo "encrypt rootfs " $1
    # Load dm-crypt.ko, it will create a special keyring for our dcp key
    insmod /lib/modules/$(uname -r)/kernel/drivers/md/dm-crypt.ko

    # Find the id of this keyring, it has the name ".dm_crypt"
    # the id changes on each reboot
    # debug: keyctl show -x
    # should show something like that:
    # Session Keyring
    #│   │    <> 0x356b9274 --alswrv      0 65534  keyring: _uid_ses.0
    #│   │    <> 0x208b7974 --alswrv      0 65534   \_ keyring: _uid.0
    #│   │    <> 0x1659b662 --alswrv      0     0       \_ keyring: .dm_crypt
    keyid=$(keyctl show -x | grep dm_crypt | cut -f 1 -d " ")

    create_key_blob

    # Load the blob into dcp
    keyctl add symmetric "mydiskkey" "dcp load_blob $(cat $keyblobpath)" $keyid
    # Activate the DM-Crypt disk, $1 is the encrypted block device
    cryptsetup open -s 128 -c aes-cbc-essiv:sha256 --type plain --key-desc mydiskkey $1 cr_disk
    # mount it
    mkdir -p ${ROOT_MNT}
    mount ${ROOT_OPT} /dev/mapper/cr_disk ${ROOT_MNT}
}

mount_pseudo_fs

echo "Initramfs Bootstrap... with encrypted rootfs ..."
parse_cmdline

#Check root device
echo "Root device: $ROOT_DEV"
if [ "$ROOT_DEV" == "" ] || [ "$ROOT_DEV" == "/dev/nfs" ]; then
    error_exit
fi

#Verify rootfs signature
echo "Verifying root partition:  $(findfs ${ROOT_DEV}) ..."
encrypt_rootfs $(findfs ${ROOT_DEV})

umount_pseudo_fs

#Switch to real root
exec switch_root ${ROOT_MNT} $INIT ${CMDLINE}
