// HBPConfiguration.m

#import "HBPConfiguration.h"

@implementation HBPConfiguration

+ (instancetype)defaultConfiguration {
    HBPConfiguration *config = [[HBPConfiguration alloc] init];

    // -----------------------------------------------------------------------
    // Remote syslog — change these before deploying.
    // -----------------------------------------------------------------------
    config.syslogHost      = @"your.syslog.host";
    config.syslogPort      = @"514";

    // -----------------------------------------------------------------------
    // Block expiry
    // -----------------------------------------------------------------------
    config.blockHours      = 24;

    // -----------------------------------------------------------------------
    // File paths — these match the paths used by the companion shell scripts.
    // -----------------------------------------------------------------------
    config.blockFile       = @"/etc/pf/blocks/arbitraryBlocks.txt";
    config.ledgerFile      = @"/etc/pf/blocks/blockLedger.txt";
    config.authlogFile     = @"/var/log/authlog";

    // -----------------------------------------------------------------------
    // Firewall table name — must match the table defined in /etc/pf.conf.
    // -----------------------------------------------------------------------
    config.pfTableName     = @"arbitraryblocks";

    // -----------------------------------------------------------------------
    // Scanning behaviour
    // -----------------------------------------------------------------------
    config.authlogTailLines = 500;

    // Replace this placeholder with the IP you never want to block (e.g. your
    // own management address).  Matching lines are skipped entirely.
    config.whitelistIP     = @"www.xxx.yyy.zzz";

    // -----------------------------------------------------------------------
    // Web-violation scanning
    // -----------------------------------------------------------------------
    config.webViolationThreshold   = 10;  // violations before blocking
    config.webViolationWindowHours = 1;   // rolling window in hours

    return config;
}

- (void)warnAboutPlaceholders {
    if ([_syslogHost isEqualToString:@"your.syslog.host"]) {
        NSLog(@"pf-blocker: WARNING: syslogHost is still set to the placeholder "
              @"'your.syslog.host'. Remote syslog logging will fail. "
              @"Edit HBPConfiguration.m and rebuild.");
    }
    if ([_whitelistIP isEqualToString:@"www.xxx.yyy.zzz"]) {
        NSLog(@"pf-blocker: WARNING: whitelistIP is still set to the placeholder "
              @"'www.xxx.yyy.zzz'. No address is currently protected from being "
              @"blocked. Replace it with your management IP in HBPConfiguration.m "
              @"and rebuild to avoid accidentally locking yourself out.");
    }
}

@end
