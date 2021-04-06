# OS Security

## Secure Boot

Secure boot ensures only authenticated software runs on the device and is achieved by verifying digital signatures of the software prior to executing the code. 
To achieve secure boot SoC support is required. NXP i.MX processors family has support for it, this feature is marketed as High Assurance Boot (HAB).

### Build a chain of Trust

A typical Linux based system has the following components:

* Bootloader

* Kernel, Device Tree

* Root Filesystem + User applications

* Application data

#### Bootloader Authentication

Bootloader Authentication is processor specific. However the mechanisms are the same :

* Creating a public/private key pair
* Signing the bootloader using vendor-specific code signing tools (CST Tool for NXP)
* Burning the public key (or hash of public key) onto One-Time programmable (OTP) fuse on the processor during Production

The processor Boot-ROM code on power-on loads the bootloader with the signature/certificates appended to it,
then authenticates the software by performing the following steps:

* Verify the public key used in the signature/certificate with the one stored in the OTP fuses
* Extract the hash of bootloader from the signature using the verified public key
* Compare the extracted hash with the computed hash of the bootloader. If it matches the boot process is continued if not it stops


![HAB Authentication](HAB1.png)


##### NXP Signing Tool (CST)

CST Tool can be downloaded from NXP Website at :
https://www.nxp.com/webapp/sps/download/license.jsp?colCode=IMX_CST_TOOL


* Certificates/keys generation:

create a serial number file that OpenSSL wil use for the certificate serial number:

        $ cd cst-2.3.3/keys
        $ echo "12345678" > serial

create a key pass file that contains a passphrase to protect the HAB code signing private keys:

        $ cd cst-2.3.3/keys
        $ echo 'xm5hg86s$ps' >  key_pass.txt
        $ echo 'xm5hg86s$ps' >> key_pass.txt

create the signature keys/certificates for hab4:

        cst-2.3.3/keys$ ./hab4_pki_tree.sh

       ...
       Do you want to use an existing CA key (y/n)?: n
       Do you want to use Elliptic Curve Cryptography (y/n)?: n
       Enter key length in bits for PKI tree: 4096
       Enter PKI tree duration (years): 10
       How many Super Root Keys should be generated? 4
       Do you want the SRK certificates to have the CA flag set? (y/n)?: y

generate the fuse table and binary hash:

        $ cd cst-2.3.3/crts
        $ ../linux64/bin/srktool -h 4 -t SRK_1_2_3_4_table.bin -e SRK_1_2_3_4_fuse.bin -d sha256 -c \
        SRK1_sha256_4096_65537_v3_ca_crt.pem,./SRK2_sha256_4096_65537_v3_ca_crt.pem,./SRK3_sha256_4096_65537_v3_ca_crt.pem,./SRK4_sha256_4096_65537_v3_ca_crt.pem -f 1
        
        
The hashes table that must be burned into the device to validate the public keys, can be generated from the fuse table above using the script:

        #!/bin/bash
        #
        # For iMX6 there are 3 banks available
        #
        bank=3
        word=0
        if [ $# -ne 1 ]; then
                echo Usage: $0  /path/to/SRK_1_2_3_4_fuse.bin
                exit 1
        fi
        for ((i=0; i<8; i++))
        do
                offset=$((i * 4))
                printf "fuse prog -y $bank $word %s\n" `hexdump -s $offset -n 4  -e '/4 "0x"' -e '/4 "%X""\n"' ${1}`
                ((word++))
        done

 a call example :
 
        imx6-hab-cst-sign$ ./imx6-u-boot_fuse_commands.sh /path/to/SRK_1_2_3_4_fuse.bin
        fuse prog -y 3 0 0x85CB70D5
        fuse prog -y 3 1 0xE3064103
        fuse prog -y 3 2 0xF372C459
        fuse prog -y 3 3 0x94C7ECBD
        fuse prog -y 3 4 0x3A98FD08
        fuse prog -y 3 5 0xFBFC10C4
        fuse prog -y 3 6 0x3007BA2B
        fuse prog -y 3 7 0xDED88E4C 
        
Once it's *absolutely* sure about what has been done so far and that  it works, you can “close” the device. 

This step is IRREVERSIBLE, better make sure there is no HAB Events in open mode configuration!!!!

        fuse prog 0 6 0x2

* Signing Process:

The first stage of HAB is the authentication of U-Boot. CST tool is used to generate the CSF data, which includes public
key, certificate, and instruction of authentication process. The CSF data is attached to the original u-boot.img. The process is
called Signature.
The IVT should be modified to contain a pointer to the CSF data. The original u-boot.img image size is around 0x27000 to
0x28000. For convenience, we first extend its size to 0x2F000 (with fill 0x5A). Then concatenate it with the CSF data. The
combined image is again extended to a fixed length (0x31000), which is used as the IVT image size parameter.
The new memory layout is shown in the following image layout:

![HAB Layout](HAB2.png)


This process is fully automated in Yocto by using the class uboot-hab-sign.bbclass which is using the default settings:


       # HAB Settings
       HAB_ENABLE= "1"
       HAB_DIR ?= "${HAB_BASE}/conf/hab"
       SRKTAB ?= "${HAB_DIR}/crts/SRK_1_2_3_4_table.bin"
       CSFK ?= "${HAB_DIR}/crts/CSF1_1_sha256_4096_65537_v3_usr_crt.pem"
       SIGN_CERT ?= "${HAB_DIR}/crts/IMG1_1_sha256_4096_65537_v3_usr_crt.pem"

U-Boot is signed then with developement Certificates/keys, For production the local.conf can be used to overwrite those settings by the productive ones.

The outcome of the process is SPL.signed and  u-boot-ivt.img-spi.signed which can be used for verified boot.

## Signed Filesystem

To extend the chain of Trust to the Applications, the Root Filesystem must be authenticated on each boot to check it's validity using Digital Signature Verification.
there are several way to achieve this goal such as dm-verity, dm-integrity, IMA/EVM,...But we chose a simple way to implement it by verifying the wohl Rootfs Partition Signature 
in Initramfs before mounting it:


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
        # +------------+ MAGIC_OFFSET(MB Aligned) |                                |
        # | Magic      |                          |                                |
        # +------------+ MAGIC_OFFSET + MAGIC_LEN -                                |
        # |            |                                                           |
        # | Signature  | <---------------------------------------------------------+
        # |            |
        # +------------+


1) The rootfs image size is aligned to MB blocks

2) Magic Header "SSI_SCXX" is appended to those blocks

3) The sum is then hashed signed and signature is the appended


The class *sign-fs.bbclass*

is automatically performing this process and is using the default settings:


        CA_CERT ?= "${HAB_DIR}/crts/CA1_sha256_4096_65537_v3_ca_crt.pem"
        ROOT_CERT ?= "${HAB_DIR}/crts/SRK1_sha256_4096_65537_v3_ca_crt.pem"
        SIGN_KEY ?= "${HAB_DIR}/keys/IMG1_1_sha256_4096_65537_v3_usr_key.pem"
        PASS_FILE ?= "${HAB_DIR}/keys/key_pass.txt"

added to machine conf or local conf will generate the signed rootfs in deploy folder:

        IMAGE_FSTYPES = "squashfs.signed"

On boot the initramfs is performing the reverse process to verify the digital signature of the rootfs:


        # +------------+  0x0 (MMC_PART_START) ----
        # |            |                          |
        # |            |                          |
        # |            |                          |
        # |            |                          |
        # | File       |                          |
        # | System     |                          |
        # .            |                          |
        # .            |                           > PAYLOAD to be verified    ----+
        # .            |                          |                                |
        # |            |                          |                                |
        # |            |                          |                                |
        # +------------+                          |                                |
        # |            |                          |                                |
        # | Fill Data  |                          |                                |
        # |            |                          |                                |
        # +------------+ MAGIC_OFFSET(MB Aligned) |                                |
        # | Magic      |                          |                                |
        # +------------+ MAGIC_OFFSET + MAGIC_LEN -                                |
        # |            |                                                           |
        # | Signature  | <---------------------------------------------------------+
        # |            |
        # +------------+


The implementation is done in *verifyfs.inc*

### encrypted rootfs (read only squashfs)

As rootfs we use a read-only squashfs (ramdisk). The rootfs is crypted
with dm-crypt with AES-128-GCM.

The class *crypt-fs.bbclass*
performs the needed steps to crypt the FS image.

As it is not a good idea to store the key in plain, we use the
DCP or CAAM for crypting the raw key and get a key blob we can store
in the SPI NOR. We store this key in the MTD Partition "key"
@ offset 0x0

### DCP usage

see implementation details in *dcp_overview.pdf*

### order of execution

We first crypt the FS image, than sign it, so on boot we first
check the signature and if the signature is OK, we encrypt the
FS image.

See the initrd script: *recipes-core/initrdscripts/files/initramfs-init.sh*

### raw key definitions

!!!

we generate with meta-scx-core a sd card image, which contains the
raw key for the crypted rootfs image (we need to create the key blob).
Do not deliver this image

!!!

define for example in auto.conf your raw key for the rootfs image:

ENC_KEY_RAW ?= "fdf6842566d47e47d6874da561fec433"

It is used in script set_keyblob.sh


CRYPT_KEY gets replaced with real value recipes-support/initfunctions/initfunctions_1.0.bb


to setup the key blob for rootfs encryption.

### setup

Intentionally using this meta layer as it is will fail your build.

You must add the keys for HAB boot, signed FS somehow to your yocto build
setup.

This can be done by simply adding another meta layer, which contains all the needed
keys.

Add this meta layer to your build and you use the default keys from there.

Of course, do not use them in your product!
