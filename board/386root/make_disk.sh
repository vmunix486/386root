#!/bin/bash
# make_disk.sh - Create a bootable syslinux disk image
# Uses a small FAT /boot partition + ext2 root partition
#
# Usage: sudo board/386root/make_disk.sh [buildroot_dir]

#set -ex

TOPDIR="${1:-.}"
BINARIES="${TOPDIR}/output/images"
HOST_DIR="${TOPDIR}/output/host"
BUILD_DIR="${TOPDIR}/output/build"
IMG_NAME="${BINARIES}/386root.img"
ROOTFS="${BINARIES}/rootfs.ext4"
IMG_SIZE_MB=64

CLEANUP_LOOPS=()
CLEANUP_DIRS=()
CLEANUP_FILES=()

cleanup() {
    for d in "${CLEANUP_DIRS[@]}"; do umount "$d" 2>/dev/null; rmdir "$d" 2>/dev/null; done
    for l in "${CLEANUP_LOOPS[@]}"; do losetup -d "$l" 2>/dev/null; done
    for f in "${CLEANUP_FILES[@]}"; do rm -f "$f"; done
}
trap cleanup EXIT

if [ "$(id -u)" -ne 0 ]; then
    echo "ERROR: must be root"
    exit 1
fi

ROOTFS=$(readlink -f "$ROOTFS")
SYSLINUX="${HOST_DIR}/usr/bin/syslinux"
MBR_BIN="${BUILD_DIR}/syslinux-4.07/mbr/mbr.bin"

echo "=== 386root disk image builder ==="

# 1. Create blank disk image
echo "[1/6] Creating ${IMG_SIZE_MB}MB disk image..."
dd if=/dev/zero of="$IMG_NAME" bs=1M count=$IMG_SIZE_MB status=progress

# 2. Partition: small FAT16 /boot + ext2 root
echo "[2/6] Creating MBR partition table..."
# Partition 1: 32MB FAT16 boot at sector 2048
# Partition 2: rest as ext2 root
sfdisk --quiet "$IMG_NAME" <<EOF
label: dos
unit: sectors

1 : start=2048,   size=65536,  type=0c, bootable
2 : start=67584,  type=83
EOF

# 3. Format partition 1 as FAT16
echo "[3/6] Formatting boot partition as FAT16..."
BOOT_LOOP=$(losetup -f --show --offset $((2048*512)) --sizelimit $((65536*512)) "$IMG_NAME")
CLEANUP_LOOPS+=("$BOOT_LOOP")
mkfs.vfat -F 16 -n BOOT "$BOOT_LOOP"

# 4. Format partition 2 as ext2
echo "[4/6] Formatting root partition as ext2..."
ROOT_LOOP=$(losetup -f --show --offset $((67584*512)) --sizelimit $(((IMG_SIZE_MB*1024*1024 - 67584*512))) "$IMG_NAME")
CLEANUP_LOOPS+=("$ROOT_LOOP")
mkfs.ext2 -F -L rootfs "$ROOT_LOOP"

# 5. Populate partitions
echo "[5/6] Populating partitions..."

# Mount root (ext2) and copy rootfs
ROOT_MNT=$(mktemp -d)
CLEANUP_DIRS+=("$ROOT_MNT")
mount "$ROOT_LOOP" "$ROOT_MNT"

SRC_MNT=$(mktemp -d)
CLEANUP_DIRS+=("$SRC_MNT")
mount -o loop,ro "$ROOTFS" "$SRC_MNT"
cp -a "$SRC_MNT"/. "$ROOT_MNT"/
umount "$SRC_MNT"
rmdir "$SRC_MNT"

# Mount boot (FAT16) and copy kernel + syslinux
BOOT_MNT=$(mktemp -d)
CLEANUP_DIRS+=("$BOOT_MNT")
mount "$BOOT_LOOP" "$BOOT_MNT"

cp "${BINARIES}/bzImage" "$BOOT_MNT/bzImage"

cat > "$BOOT_MNT/syslinux.cfg" <<SYSLINUX
DEFAULT linux
TIMEOUT 20
PROMPT 1

LABEL linux
    LINUX /bzImage
    APPEND root=/dev/sda2 rw rootwait console=ttyS0,115200 console=tty0
SYSLINUX

# Install syslinux on the FAT partition
"$SYSLINUX" "$BOOT_LOOP"
sync

echo "Boot partition contents:"
ls -la "$BOOT_MNT/"

umount "$BOOT_MNT"
rmdir "$BOOT_MNT"
umount "$ROOT_MNT"
rmdir "$ROOT_MNT"

# 6. Write MBR bootstrap
echo "[6/6] Writing MBR bootstrap..."
dd if="$MBR_BIN" of="$IMG_NAME" bs=440 count=1 conv=notrunc

echo ""
echo "=== Done! ==="
chown "$(id -u):$(id -g)" "$IMG_NAME"
echo "  qemu-system-i386 -hda ${IMG_NAME} -nographic -m 256M"
