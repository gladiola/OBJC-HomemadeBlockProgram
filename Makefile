# Build flags come from gnustep-config so they work on any GNUstep platform
# (OpenBSD with pkg_add gnustep-make gnustep-base libobjc2, or Linux).
CC      = cc
CFLAGS  = $(shell gnustep-config --objc-flags) -fobjc-arc
LDFLAGS = $(shell gnustep-config --base-libs)

TARGET = pf-blocker
SRCS   = main.m \
         HBPConfiguration.m \
         HBPAuthLogScanner.m \
         HBPBlockManager.m \
         HBPViolationScanner.m

TEST_TARGET = tests/test_pf_blocker
TEST_SRCS   = tests/test_pf_blocker.m \
              HBPConfiguration.m \
              HBPAuthLogScanner.m \
              HBPViolationScanner.m \
              HBPBlockManager.m

all: $(TARGET)

$(TARGET): $(SRCS)
	$(CC) $(CFLAGS) -o $(TARGET) $(SRCS) $(LDFLAGS)

test: $(TEST_TARGET)
	./$(TEST_TARGET)

$(TEST_TARGET): $(TEST_SRCS)
	$(CC) $(CFLAGS) -o $(TEST_TARGET) $(TEST_SRCS) $(LDFLAGS)

clean:
	rm -f $(TARGET) $(TEST_TARGET)

install:
	install -m 0755 $(TARGET) /usr/local/sbin/pf-blocker

.PHONY: all test clean install
