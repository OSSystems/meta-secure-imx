# Understanding the i.MX8M family flash.bin image layout

Due to the new the architecture, multiple firmwares and softwares are required
to boot i.MX8M family devices. In order to store all the images in a single
binary the FIT (Flattened Image Tree) image structure is used.

This approach does not use anymore the imx-mkimage project, as
mainline U-Boot deprecates the use of CONFIG_SPL_FIT_GENERATOR.

With this there is no need to scan U-Boot logs anymore, instead
the infos we need for signing the SPL and U-Boot image can be
extracted from the images itself.

For a secure boot process users should ensure all images included
in SPL and u-boot.itb files are covered by a digital signature.

- The diagram below illustrate a signed image layout:

```
                     +-----------------------------+
                     |                             |
                     |     *Signed HDMI/DP FW      |
                     |                             |
                     +-----------------------------+
                     |           Padding           |
             ------- +-----------------------------+ --------
                 ^   |          IVT - SPL          |   ^
          Signed |   +-----------------------------+   |
           Data  |   |        u-boot-spl.bin       |   |
                 |   |              +              |   |  SPL
                 v   |           DDR FW            |   | Image
             ------- +-----------------------------+   |
                     |      CSF - SPL + DDR FW     |   v
                     +-----------------------------+ --------
                     |           Padding           |
             ------- +-----------------------------+ --------
          Signed ^   |          FDT - FIT          |   ^
           Data  |   +-----------------------------+   |
                 v   |          IVT - FIT          |   |
             ------- +-----------------------------+   |
                     |          CSF - FIT          |   |
             ------- +-----------------------------+   |  FIT
                 ^   |       u-boot-nodtb.bin      |   | Image
                 |   +-----------------------------+   |
          Signed |   |       OP-TEE (Optional)     |   |
           Data  |   +-----------------------------+   |
                 |   |        bl31.bin (ATF)       |   |
                 |   +-----------------------------+   |
                 v   |          u-boot.dtb         |   v
             ------- +-----------------------------+ --------
  * Only supported on i.MX8M series
```

The boot flow on i.MX8M devices are slightly different when compared with i.MX6
and i.MX7 series, the diagram below illustrate the boot sequence overview:

- i.MX8M boot flow:

```
                  Secure World                     Non-Secure World
                                         |
                                         |
  +------------+      +------------+     |
  |     SPL    |      |  i.MX 8M   |     |
  |      +     | ---> |    ROM     |     |
  |   DDR FW   |      |   + HAB    |     |
  +------------+      +------------+     |
                             |           |
                             v           |
                      +------------+     |
                      |  *Signed   |     |
                      | HDMI/DP FW |     |
                      +------------+     |
                             |           |
                             v           |
  +------------+      +------------+     |
  | FIT Image: |      |     SPL    |     |
  | ATF + TEE  | ---> |      +     |     |
  |  + U-Boot  |      |   DDR FW   |     |      +-----------+
  +------------+      +------------+     |      |   Linux   |
                             |           |      +-----------+
                             v           |            ^
                      +------------+     |            |             +-------+
                      |    ARM     |     |      +-----------+       | Linux |
                      |  Trusted   | ----+--->  |   U-Boot  |  <--- |   +   |
                      |  Firmware  |     |      +-----------+       |  DTB  |
                      +------------+     |                          +-------+
                             |           |
                             v           |
                       +----------+      |
                       | **OP-TEE |      |
                       +----------+      |
  * Only supported on i.MX8M series
  ** Optional
```

Particularly on the i.MX8M, the HDMI firmware or DisplayPort firmware are the
first image to boot on the device. These firmwares are signed and distributed by
NXP, and are always authenticated regardless of security configuration. In case
not required by the application the HDMI or DisplayPort controllers can be
disabled by eFuses and the firmwares are not required anymore.

The next images are not signed by NXP and users should follow the signing
procedure as described in this document.

The Second Program Loader (SPL) and DDR firmware are loaded and authenticated
by the ROM code, these images are executed in the internal RAM and responsible
for initializing essential features such as DDR, UART, PMIC and clock
enablement.

Once the DDR is available, the SPL code loads all the images included in the
FIT structure to their specific execution addresses, the HAB APIs are called
to extend the root of trust, authenticating the U-Boot, ARM trusted firmware
(ATF) and OP-TEE (If included).

The root of trust can be extended again at U-Boot level to authenticate Kernel
and M4 images.

# Enabling the secure boot support in U-Boot

The first step is to generate an U-Boot image supporting the HAB features,
similar to i.MX6 and i.MX7 series the U-Boot provides extra functions for
HAB, such as the HAB status logs retrievement through the hab_status command
and support to extend the root of trust.

The support is enabled by adding the CONFIG_IMX_HAB to the build
configuration:

- Defconfig:

  CONFIG_IMX_HAB=y

As mainline U-Boot states:

	This board uses CONFIG_SPL_FIT_GENERATOR. Please migrate
	to binman instead, to avoid the proliferation of
	arch-specific scripts with no tests.

So be sure to disable ```CONFIG_SPL_FIT_GENERATOR```

# Signing

## Avoiding Kernel crash in closed devices

For devices prior to HAB v4.4.0, the HAB code locks the Job Ring and DECO
master ID registers in closed configuration. In case the user specific
application requires any changes in CAAM MID registers it's necessary to
add the "Unlock CAAM MID" command in CSF file.

The current NXP BSP implementation expects the CAAM registers to be unlocked
when configuring CAAM to operate in non-secure TrustZone world.

The Unlock command is already included by default in the signed HDMI and
DisplayPort firmwares. On i.MX8MM, i.MX8MN and i.MX8MP devices or in case the
HDMI or DisplayPort controllers are disabled in i.MX8M, users must ensure this
command is included in SPL CSF.

- Add Unlock MID command in csf_spl.txt:

```
	[Unlock]
	      Engine = CAAM
	      Features = MID
```

## Signing Images

[uboot-hab-sign.bbclass](classes/uboot-hab-sign.bbclass)

This class does the following steps:

- Create the csf description files for SPL and u-boot.itb
- create IVT Header for u-bot.itb
- create the signed data for SPL and u-boot.itb
- create the files SPL.signed (copy from SPL) and insert
  signed data
- create the files u-boot.itb.signed (copy from u-boot.itb) and insert
  signed data

So at the end you have the files SPL.signed and u-boot.itb.signed
you can burn onto sd card or into SPI flash.

# program SRK Hash

As explained in AN4581[1] and in introduction_habv4.txt document the SRK Hash
fuse values are generated by the srktool and should be programmed in the
SoC SRK_HASH[255:0] fuses.

Be careful when programming these values, as this data is the basis for the
root of trust. An error in SRK Hash results in a part that does not boot.

The U-Boot fuse tool can be used for programming eFuses on i.MX SoCs.

- Dump SRK Hash fuses values in host machine:

```
	$ hexdump -e '/4 "0x"' -e '/4 "%X""\n"' < SRK_1_2_3_4_fuse.bin
	0xEA248E6E
	0xA7B83DAB
	0x867C100
	0x44946844
	0xAAB0B079
	0x9A514114
	0x78E06A05
	0x25808D13
```

Values must differ for your setup!

- Program SRK_HASH[255:0] fuses on i.MX8M family devices:

```
	=> fuse prog -y 6 0 0xEA248E6E
	=> fuse prog -y 6 1 0xA7B83DAB
	=> fuse prog -y 6 2 0x867C100
	=> fuse prog -y 6 3 0x44946844
	=> fuse prog -y 7 0 0xAAB0B079
	=> fuse prog -y 7 1 0x9A514114
	=> fuse prog -y 7 2 0x78E06A05
	=> fuse prog -y 7 3 0x25808D13
```

Values must differ for your setup!

# Verifying HAB events

The next step is to verify that the signatures in your images are
successfully processed without errors. HAB generates events when
processing the commands if it encounters issues.

The hab_status U-Boot command call the hab_report_event() and hab_status()
HAB API functions to verify the processor security configuration and status.
This command displays any events that were generated during the process.

Prior to closing the device users should ensure no HAB events were found, as
the example below:

- Verify HAB events:

	=> hab_status
	
	Secure boot disabled
	
	HAB Configuration: 0xf0, HAB State: 0x66

# Close the device

Once it's *absolutely* sure about what has been done so far and that it works, you can “close” the device. 

This is the last step in the HAB process, and is achieved by programming the SEC_CONFIG[1] fuse bit.

Once the fuse is programmed, the chip does not load an image that has not been
signed using the correct PKI tree.

- Program SEC_CONFIG[1] fuse on i.MX8M family devices:

	=> fuse prog 1 3 0x2000000


References:
[1] AN4581: "i.MX Secure Boot on HABv4 Supported Devices"
