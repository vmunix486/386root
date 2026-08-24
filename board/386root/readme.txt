386root - A Linux distribution for Intel 386
=============================================

A minimal Linux distribution built with Buildroot 2016.02, targeting
true Intel 386 processors. Uses the custom 386linux kernel 3.7.10
from https://github.com/vmunix486/386linux.

Features:
- Intel 386 CPU target (CONFIG_M386)
- uClibc-ng C library (lightweight, suitable for old hardware)
- BusyBox init system and utilities
- ext4 filesystem support
- Basic networking (TCP/IP)
- Serial console on ttyS0 at 115200 baud
- Math emulation for 386 without FPU
- Syslinux/Extlinux bootloader for bootable disk images

Building:

  make 386root_defconfig
  make

Testing in QEMU (quick test, no bootloader needed):

  qemu-system-i386 \
    -M pc \
    -m 256M \
    -kernel output/images/bzImage \
    -hda output/images/rootfs.ext4 \
    -append "root=/dev/sda rw console=ttyS0,115200" \
    -nographic

Creating a bootable disk image (requires root):

  sudo board/386root/make_disk.sh

  This creates output/images/386root.img with extlinux bootloader,
  kernel, and root filesystem in a single MBR-partitioned image.

  Test the disk image:
    qemu-system-i386 -hda output/images/386root.img -nographic -m 256M

  Write to USB (replace sdX):
    sudo dd if=output/images/386root.img of=/dev/sdX bs=4M status=progress

Testing in 86box / real hardware:

  1. Create a new VM with Intel 386 CPU, 256 MB RAM
  2. Boot from the 386root.img disk image, or write it to a
     physical disk/CF card/USB stick

Notes:
- The kernel is configured with NOHIGHMEM (no high memory support),
  suitable for 386 systems with less than 512 MB RAM.
- Math emulation is enabled for 386 CPUs without a FPU.
- NPTL is not available for true 386 (no threading library support).
- The ext4 image size is auto-calculated based on content. Extra free
  space can be added with BR2_TARGET_ROOTFS_EXT2_EXTRA_BLOCKS.
