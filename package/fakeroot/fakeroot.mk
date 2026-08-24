################################################################################
#
# fakeroot
#
################################################################################

FAKEROOT_VERSION = 1.31
FAKEROOT_SOURCE = fakeroot_$(FAKEROOT_VERSION).orig.tar.gz
FAKEROOT_SITE = http://deb.debian.org/debian/pool/main/f/fakeroot
# Force capabilities detection off
# For now these are process capabilities (faked) rather than file
# so they're of no real use
HOST_FAKEROOT_CONF_ENV = \
	ac_cv_header_sys_capability_h=no \
	ac_cv_func_capset=no

FAKEROOT_LICENSE = GPLv3+
FAKEROOT_LICENSE_FILES = COPYING

$(eval $(host-autotools-package))
