################################################################################
#
# ucl
#
################################################################################

UCL_VERSION = 1.03
UCL_SITE = http://www.oberhumer.com/opensource/ucl/download
UCL_LICENSE = GPLv2+
UCL_LICENSE_FILES = COPYING
# ACC conformance test and various checks fail with GCC 14's stricter
# C17/C23 defaults; force gnu89 and suppress warnings
HOST_UCL_CONF_ENV = CFLAGS="-O2 -std=gnu89 -w"

$(eval $(host-autotools-package))
