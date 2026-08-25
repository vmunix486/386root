#!/bin/bash
# make_disk.sh - Create a bootable GRUB Legacy disk image
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
PART_OFFSET_SECTORS=2048
# CHS geometry for old BIOSes: 16 heads, 63 sectors/track
HEADS=16
SECS_PER_TRACK=63

CLEANUP_LOOPS=()
CLEANUP_DIRS=()

cleanup() {
    for d in "${CLEANUP_DIRS[@]}"; do umount "$d" 2>/dev/null; rmdir "$d" 2>/dev/null; done
    for l in "${CLEANUP_LOOPS[@]}"; do losetup -d "$l" 2>/dev/null; done
}
trap cleanup EXIT

if [ "$(id -u)" -ne 0 ]; then
    echo "ERROR: must be root"
    exit 1
fi

ROOTFS=$(readlink -f "$ROOTFS")
GRUB_STAGE_DIR="${TARGET_DIR:-${TOPDIR}/output/target}/boot/grub"
GRUB_BIN="${HOST_DIR}/sbin/grub"

echo "=== 386root GRUB disk image builder ==="

# 1. Create blank disk image
echo "[1/5] Creating ${IMG_SIZE_MB}MB disk image..."
dd if=/dev/zero of="$IMG_NAME" bs=1M count=$IMG_SIZE_MB status=progress

# 2. Partition with MBR
echo "[2/5] Creating MBR partition table..."
sfdisk --quiet "$IMG_NAME" <<EOF
label: dos
unit: sectors

1 : start=$PART_OFFSET_SECTORS, type=83, bootable
EOF

# 3. Create ext2 filesystem on partition
PART_SIZE_KB=$(( (IMG_SIZE_MB * 1024 * 1024 - PART_OFFSET_SECTORS * 512) / 1024 ))
PART_LOOP=$(losetup -f --show --offset $((PART_OFFSET_SECTORS * 512)) --sizelimit $((PART_SIZE_KB * 1024)) "$IMG_NAME")
CLEANUP_LOOPS+=("$PART_LOOP")
mkfs.ext2 -F -L rootfs "$PART_LOOP"

# 4. Mount partition, populate it
echo "[3/5] Populating filesystem..."
TMPMNT=$(mktemp -d)
CLEANUP_DIRS+=("$TMPMNT")
mount "$PART_LOOP" "$TMPMNT"

# Copy rootfs
TMPSRC=$(mktemp -d)
CLEANUP_DIRS+=("$TMPSRC")
mount -o loop,ro "$ROOTFS" "$TMPSRC"
cp -a "$TMPSRC"/. "$TMPMNT"/
umount "$TMPSRC"
rmdir "$TMPSRC"

# Copy kernel
mkdir -p "$TMPMNT/boot"
cp "${BINARIES}/bzImage" "$TMPMNT/boot/bzImage"

# Create GRUB menu.lst
mkdir -p "$TMPMNT/boot/grub"
cat > "$TMPMNT/boot/grub/menu.lst" <<GRUB
default 0
timeout 20
color white/blue black/light-gray

title 386root (VGA console)
    root (hd0,0)
    kernel /boot/bzImage root=/dev/sda1 rw console=tty0

title 386root (Serial console)
    root (hd0,0)
    kernel /boot/bzImage root=/dev/sda1 rw console=ttyS0,115200
GRUB

# Copy GRUB stage files
if [ -d "$GRUB_STAGE_DIR" ]; then
    cp "$GRUB_STAGE_DIR"/stage1 "$TMPMNT/boot/grub/" 2>/dev/null || true
    cp "$GRUB_STAGE_DIR"/*_stage1_5 "$TMPMNT/boot/grub/" 2>/dev/null || true
    cp "$GRUB_STAGE_DIR"/stage2 "$TMPMNT/boot/grub/" 2>/dev/null || true
fi

echo "Filesystem contents:"
find "$TMPMNT/boot" -ls

umount "$TMPMNT"
rmdir "$TMPMNT"

# 5. Install GRUB to MBR
echo "[4/5] Installing GRUB to MBR..."
# Calculate total cylinders
TOTAL_SECTORS=$((IMG_SIZE_MB * 1024 * 2))
CYLINDERS=$((TOTAL_SECTORS / (HEADS * SECS_PER_TRACK)))

# Calculate partition start cylinder
PART_START_CYL=$((PART_OFFSET_SECTORS / (HEADS * SECS_PER_TRACK)))

"$GRUB_BIN" --batch --device-map=/dev/null <<GRUB_CMDS
device (hd0) ${IMG_NAME}
geometry (hd0) ${CYLINDERS} ${HEADS} ${SECS_PER_TRACK}
root (hd0,0)
setup (hd0)
quit
GRUB_CMDS

echo "[5/5] Done!"
chown "$(id -u):$(id -g)" "$IMG_NAME"

echo ""
echo "=== Disk image ready: ${IMG_NAME} ==="
echo "  qemu-system-i386 -hda ${IMG_NAME} -nographic -m 256M"
