################################################################################
#
# syslinux to make target msdos/iso9660 filesystems bootable
#
################################################################################

SYSLINUX_VERSION = 4.07
SYSLINUX_SOURCE = syslinux-$(SYSLINUX_VERSION).tar.xz
SYSLINUX_SITE = $(BR2_KERNEL_MIRROR)/linux/utils/boot/syslinux

SYSLINUX_LICENSE = GPLv2+
SYSLINUX_LICENSE_FILES = COPYING

SYSLINUX_INSTALL_IMAGES = YES

SYSLINUX_DEPENDENCIES = host-nasm host-util-linux host-upx

ifeq ($(BR2_TARGET_SYSLINUX_LEGACY_BIOS),y)
SYSLINUX_TARGET = bios
endif

# The syslinux build system must be forced to use Buildroot's gnu-efi
# package by setting EFIINC, LIBDIR and LIBEFI. Otherwise, it uses its
# own copy of gnu-efi included in syslinux's sources since 6.03
# release.
ifeq ($(BR2_TARGET_SYSLINUX_EFI),y)
ifeq ($(BR2_ARCH_IS_64),y)
SYSLINUX_EFI_BITS = efi64
else
SYSLINUX_EFI_BITS = efi32
endif # 64-bit
SYSLINUX_DEPENDENCIES += gnu-efi
SYSLINUX_TARGET = $(SYSLINUX_EFI_BITS)
SYSLINUX_EFI_ARGS = \
	EFIINC=$(STAGING_DIR)/usr/include/efi \
	LIBDIR=$(STAGING_DIR)/usr/lib \
	LIBEFI=$(STAGING_DIR)/usr/lib/libefi.a
endif # EFI

# The syslinux tarball comes with pre-compiled binaries.
# Since timestamps might not be in the correct order, a rebuild
# is not always triggered for all the different images.
# Cleanup the mess even before we attempt a build, so we indeed
# build everything from source.
define SYSLINUX_CLEANUP
	rm -rf $(@D)/bios $(@D)/efi32 $(@D)/efi64
endef
SYSLINUX_POST_PATCH_HOOKS += SYSLINUX_CLEANUP

# Syslinux's mk/syslinux.mk hardcodes "CC = gcc" which overrides
# command-line CC. Change to ?= so our CC takes precedence.
define SYSLINUX_FIXUP_CC
	$(SED) 's/^CC\t= gcc/CC\t?= gcc/' $(@D)/mk/syslinux.mk
endef
SYSLINUX_POST_PATCH_HOOKS += SYSLINUX_FIXUP_CC

# GCC 14+ is stricter about implicit declarations, implicit int,
# incompatible pointer types, and fallthrough. Also needs -fcommon
# for tentative global definitions, and -std=gnu89 to avoid
# variable-length array errors in ACC compile-time assert macros.
SYSLINUX_GCC14_CC = $(HOSTCC) -std=gnu89 \
	-Wno-implicit-function-declaration \
	-Wno-implicit-int \
	-Wno-int-conversion \
	-Wno-incompatible-pointer-types \
	-Wno-implicit-fallthrough \
	-fcommon

ifeq ($(BR2_TARGET_SYSLINUX_LEGACY_BIOS),y)
# Build only what we need: com32 libs, lzo, core (boot loader), memdisk,
# modules, mbr, libinstaller, and the extlinux installer.
# Skip gpxe (network boot), diag, dos, win32/win64, dosutil.
define SYSLINUX_BUILD_CMDS
	$(TARGET_MAKE_ENV) $(MAKE1) -C $(@D) \
		CC="$(SYSLINUX_GCC14_CC)" \
		AR="$(HOSTAR)" \
		all-local
	for i in codepage com32 lzo core memdisk modules mbr memdump \
		 sample libinstaller linux extlinux utils; do \
		$(TARGET_MAKE_ENV) $(MAKE1) -C $(@D)/$$i \
			CC="$(SYSLINUX_GCC14_CC)" \
			AR="$(HOSTAR)" \
			all || exit 1; \
	done
endef
endif

ifeq ($(BR2_TARGET_SYSLINUX_EFI),y)
define SYSLINUX_BUILD_CMDS
	$(TARGET_MAKE_ENV) $(MAKE1) -C $(@D) \
		CC="$(SYSLINUX_GCC14_CC)" \
		AR="$(HOSTAR)" \
		$(SYSLINUX_EFI_ARGS) \
		all
endef
endif

# Syslinux 4.07: install manually to HOST_DIR
define SYSLINUX_INSTALL_TARGET_CMDS
	mkdir -p $(HOST_DIR)/usr/bin
	$(INSTALL) -D -m 0755 $(@D)/mtools/syslinux $(HOST_DIR)/usr/bin/syslinux
	mkdir -p $(HOST_DIR)/usr/sbin
	$(INSTALL) -D -m 0755 $(@D)/extlinux/extlinux $(HOST_DIR)/usr/sbin/extlinux
	mkdir -p $(HOST_DIR)/usr/share/syslinux
	$(INSTALL) -D -m 0644 $(@D)/core/ldlinux.c32 $(HOST_DIR)/usr/share/syslinux/ldlinux.c32 2>/dev/null || true
endef

SYSLINUX_IMAGES-$(BR2_TARGET_SYSLINUX_ISOLINUX) += core/isolinux.bin
SYSLINUX_IMAGES-$(BR2_TARGET_SYSLINUX_PXELINUX) += core/pxelinux.bin
SYSLINUX_IMAGES-$(BR2_TARGET_SYSLINUX_MBR) += mbr/mbr.bin
SYSLINUX_IMAGES-$(BR2_TARGET_SYSLINUX_EFI) += $(SYSLINUX_EFI_BITS)/efi/syslinux.efi

SYSLINUX_C32 = $(call qstrip,$(BR2_TARGET_SYSLINUX_C32))

define SYSLINUX_INSTALL_IMAGES_CMDS
	mkdir -p $(BINARIES_DIR)/syslinux
	for i in $(SYSLINUX_IMAGES-y); do \
		$(INSTALL) -D -m 0755 $(@D)/$$i $(BINARIES_DIR)/syslinux/$${i##*/}; \
	done
	for i in $(SYSLINUX_C32); do \
		$(INSTALL) -D -m 0755 $(HOST_DIR)/usr/share/syslinux/$${i} \
			$(BINARIES_DIR)/syslinux/$${i}; \
	done
endef

$(eval $(generic-package))
