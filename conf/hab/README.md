# Steps to flash security keys into u-boot:
- Build the SPL and u-boot (without security on)
- Flash SPL and u-boot in SD card. Replace "sdX" with your block device
```shell
sudo dd if=./SPL of=/dev/sdX bs=512 seek=2 oflag=sync status=progress
sudo dd if=./uboot of=/dev/sdX bs=1024 seek=69 oflag=sync status=progress
```

- Connect UART debug to host
- Insert and power on the target
- Interrupt u-boot autoboot
- Get the keys used from conf/hab/crts/SRK_1_2_3_4_fuse.bin
```shell
hexdump -e '/4 "0x"' -e '/4 "%X""\n"' < conf/hab/crts/SRK_1_2_3_4_fuse.bin
0xFC76DE67
0x38786AF5
0x5B7BCE42
0x5E1BAE2
0xDF068E6
0x3B298390
0x525CD002
0x257A5A07
```
- Fuse the security keys as below
```shell
fuse prog -y 3 0 0xFC76DE67
fuse prog -y 3 1 0x38786AF5
fuse prog -y 3 2 0x5B7BCE42
fuse prog -y 3 3 0x5E1BAE2
fuse prog -y 3 4 0xDF068E6
fuse prog -y 3 5 0x3B298390
fuse prog -y 3 6 0x525CD002
fuse prog -y 3 7 0x257A5A07
```
