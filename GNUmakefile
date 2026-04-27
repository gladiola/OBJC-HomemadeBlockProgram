# GNUmakefile — builds pf-blocker with the GNUstep build system.
#
# Prerequisites on OpenBSD:
#   pkg_add gnustep-make gnustep-base
#   . /usr/local/share/GNUstep/Makefiles/GNUstep.sh
#
# Then just run:
#   make
#   sudo make install
#
# The compiled tool is installed to $(GNUSTEP_LOCAL_TOOLS), which is
# typically /usr/local/bin.  Copy or symlink it to /usr/local/sbin/ if
# you prefer that location.

include $(GNUSTEP_MAKEFILES)/common.make

TOOL_NAME = pf-blocker

pf-blocker_OBJC_FILES = \
	main.m \
	HBPConfiguration.m \
	HBPAuthLogScanner.m \
	HBPBlockManager.m

pf-blocker_OBJCFLAGS = -fobjc-arc

include $(GNUSTEP_MAKEFILES)/tool.make
