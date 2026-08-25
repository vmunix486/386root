################################################################################
#
# grub
#
################################################################################

GRUB_VERSION = 0.97
GRUB_SOURCE = grub_$(GRUB_VERSION).orig.tar.gz
GRUB_PATCH = grub_$(GRUB_VERSION)-68.diff.gz
GRUB_SITE = http://snapshot.debian.org/archive/debian/20141023T043132Z/pool/main/g/grub

GRUB_LICENSE = GPLv2+
GRUB_LICENSE_FILES = COPYING

GRUB_CONFIG-y += $(if $(BR2_TARGET_GRUB_SPLASH),--enable-graphics,--disable-graphics)

GRUB_CONFIG-$(BR2_TARGET_GRUB_DISKLESS) += --enable-diskless
GRUB_CONFIG-$(BR2_TARGET_GRUB_3c595) += --enable-3c595
GRUB_CONFIG-$(BR2_TARGET_GRUB_3c90x) += --enable-3c90x
GRUB_CONFIG-$(BR2_TARGET_GRUB_davicom) += --enable-davicom
GRUB_CONFIG-$(BR2_TARGET_GRUB_e1000) += --enable-e1000
GRUB_CONFIG-$(BR2_TARGET_GRUB_eepro100) += --enable-eepro100
GRUB_CONFIG-$(BR2_TARGET_GRUB_epic100) += --enable-epic100
GRUB_CONFIG-$(BR2_TARGET_GRUB_forcedeth) += --enable-forcedeth
GRUB_CONFIG-$(BR2_TARGET_GRUB_natsemi) += --enable-natsemi
GRUB_CONFIG-$(BR2_TARGET_GRUB_ns83820) += --enable-ns83820
GRUB_CONFIG-$(BR2_TARGET_GRUB_ns8390) += --enable-ns8390
GRUB_CONFIG-$(BR2_TARGET_GRUB_pcnet32) += --enable-pcnet32
GRUB_CONFIG-$(BR2_TARGET_GRUB_pnic) += --enable-pnic
GRUB_CONFIG-$(BR2_TARGET_GRUB_rtl8139) += --enable-rtl8139
GRUB_CONFIG-$(BR2_TARGET_GRUB_r8169) += --enable-r8169
GRUB_CONFIG-$(BR2_TARGET_GRUB_sis900) += --enable-sis900
GRUB_CONFIG-$(BR2_TARGET_GRUB_tg3) += --enable-tg3
GRUB_CONFIG-$(BR2_TARGET_GRUB_tulip) += --enable-tulip
GRUB_CONFIG-$(BR2_TARGET_GRUB_tlan) += --enable-tlan
GRUB_CONFIG-$(BR2_TARGET_GRUB_undi) += --enable-undi
GRUB_CONFIG-$(BR2_TARGET_GRUB_via_rhine) += --enable-via-rhine
GRUB_CONFIG-$(BR2_TARGET_GRUB_w89c840) += --enable-w89c840

GRUB_CONFIG-y += $(if $(BR2_TARGET_GRUB_FS_EXT2),--enable-ext2fs,--disable-ext2fs)
GRUB_CONFIG-y += $(if $(BR2_TARGET_GRUB_FS_FAT),--enable-fat,--disable-fat)
GRUB_CONFIG-y += $(if $(BR2_TARGET_GRUB_FS_ISO9660),--enable-iso9660,--disable-iso9660)
GRUB_CONFIG-y += $(if $(BR2_TARGET_GRUB_FS_JFS),--enable-jfs,--disable-jfs)
GRUB_CONFIG-y += $(if $(BR2_TARGET_GRUB_FS_REISERFS),--enable-reiserfs,--disable-reiserfs)
GRUB_CONFIG-y += $(if $(BR2_TARGET_GRUB_FS_XFS),--enable-xfs,--disable-xfs)
GRUB_CONFIG-y += --disable-ffs --disable-ufs2 --disable-minix --disable-vstafs

GRUB_STAGE_1_5_TO_INSTALL += $(if $(BR2_TARGET_GRUB_FS_EXT2),e2fs)
GRUB_STAGE_1_5_TO_INSTALL += $(if $(BR2_TARGET_GRUB_FS_FAT),fat)
GRUB_STAGE_1_5_TO_INSTALL += $(if $(BR2_TARGET_GRUB_FS_ISO9660),iso9660)
GRUB_STAGE_1_5_TO_INSTALL += $(if $(BR2_TARGET_GRUB_FS_JFS),jfs)
GRUB_STAGE_1_5_TO_INSTALL += $(if $(BR2_TARGET_GRUB_FS_REISERFS),reiserfs)
GRUB_STAGE_1_5_TO_INSTALL += $(if $(BR2_TARGET_GRUB_FS_XFS),xfs)

define GRUB_DEBIAN_PATCHES
	# Apply the patches from the Debian patch
	(cd $(@D) ; for f in `cat debian/patches/series | grep -v ^#` ; do \
		cat debian/patches/$$f | patch -g0 -p1 ; \
	done)
endef

GRUB_POST_PATCH_HOOKS += GRUB_DEBIAN_PATCHES

# GRUB 0.97 must be built as a native host tool (not cross-compiled).
# The autotools-package infrastructure hardcodes --host=$(GNU_TARGET_NAME)
# after CONF_OPTS, so overriding CONF_OPTS/CONF_ENV doesn't help.
# We must define our own configure command to bypass the infrastructure.
GRUB_CONF_OPTS = \
	--build=x86_64-pc-linux-gnu \
	--host=x86_64-pc-linux-gnu \
	--disable-auto-linux-mem-opt \
	$(GRUB_CONFIG-y)

define GRUB_CONFIGURE_CMDS
	echo 'grub_cv_prog_objcopy_absolute=yes' > $(@D)/../grub.cache && \
	(cd $(@D) && rm -rf config.cache && \
	CC="/usr/bin/gcc -m32" \
	CXX="/usr/bin/g++ -m32" \
	LD="/usr/bin/ld -m elf_i386" \
	AR="/usr/bin/ar" \
	RANLIB="/usr/bin/ranlib" \
	STRIP="/usr/bin/strip" \
	NM="/usr/bin/nm" \
	CFLAGS="-O0 -m32 -march=i386 -std=gnu89 -DSUPPORT_LOOPDEV -fno-stack-protector -fno-pie -no-pie -Wno-error -Wno-implicit-function-declaration -Wno-implicit-int -Wno-incompatible-pointer-types -Wno-int-conversion" \
	CPPFLAGS="-m32" \
	LDFLAGS="-m32 -march=i386 -no-pie -Wl,--build-id=none" \
	CONFIG_SITE=/dev/null \
	./configure \
		--build=x86_64-pc-linux-gnu \
		--host=x86_64-pc-linux-gnu \
		--prefix=$(HOST_DIR)/usr \
		--sysconfdir=$(HOST_DIR)/etc \
		--localstatedir=$(HOST_DIR)/var \
		--cache-file=$(@D)/../grub.cache \
		$(GRUB_CONF_OPTS))
endef

ifeq ($(BR2_TARGET_GRUB_SPLASH),y)
define GRUB_INSTALL_SPLASH
	$(INSTALL) -D -m 0644 boot/grub/splash.xpm.gz $(TARGET_DIR)/boot/grub/splash.xpm.gz
endef
else
define GRUB_INSTALL_SPLASH
	$(SED) '/^splashimage/d' $(TARGET_DIR)/boot/grub/menu.lst
endef
endif

# Install grub binary to host, stage files to target
define GRUB_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0755 $(@D)/grub/grub $(HOST_DIR)/sbin/grub
	$(INSTALL) -D -m 0755 $(@D)/stage1/stage1 $(TARGET_DIR)/boot/grub/stage1
	for f in $(GRUB_STAGE_1_5_TO_INSTALL) ; do \
		$(INSTALL) -D -m 0755 $(@D)/stage2/$${f}_stage1_5 \
			$(TARGET_DIR)/boot/grub/$${f}_stage1_5 ; \
	done
	$(INSTALL) -D -m 0644 $(@D)/stage2/stage2 $(TARGET_DIR)/boot/grub/stage2
	$(INSTALL) -D -m 0644 boot/grub/menu.lst $(TARGET_DIR)/boot/grub/menu.lst
	$(GRUB_INSTALL_SPLASH)
endef

$(eval $(autotools-package))
