# Build flags come from gnustep-config so they work on any GNUstep platform
# (OpenBSD with pkg_add gnustep-make gnustep-base libobjc2, or Linux).
CC      = cc
CFLAGS  = $(shell gnustep-config --objc-flags)
LDFLAGS = $(shell gnustep-config --base-libs)

TARGET = pf-blocker
SRCS   = main.m \
         HBPConfiguration.m \
         HBPAuthLogScanner.m \
         HBPBlockManager.m \
         HBPViolationScanner.m

all: $(TARGET)

$(TARGET): $(SRCS)
	$(CC) $(CFLAGS) -o $(TARGET) $(SRCS) $(LDFLAGS)

clean:
	rm -f $(TARGET)

install:
	install -m 0755 $(TARGET) /usr/local/sbin/pf-blocker

.PHONY: all clean install
