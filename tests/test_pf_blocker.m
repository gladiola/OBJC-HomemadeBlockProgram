#import <Foundation/Foundation.h>
#import "../HBPConfiguration.h"
#import "../HBPAuthLogScanner.h"
#import "../HBPViolationScanner.h"
#import "../HBPBlockManager.h"

/* ── Minimal test framework ────────────────────────────────────────────── */

static int g_passed = 0;
static int g_failed = 0;

#define ASSERT(desc, expr)                                               \
    do {                                                                 \
        if (expr) {                                                      \
            g_passed++;                                                  \
            fprintf(stdout, "PASS: %s\n", (desc));                      \
        } else {                                                         \
            g_failed++;                                                  \
            fprintf(stderr, "FAIL: %s  (line %d)\n", (desc), __LINE__); \
        }                                                                \
    } while (0)

/* ── Helpers ───────────────────────────────────────────────────────────── */

/* Write content to a unique temp file and return its path. */
static NSString *writeTempFile(NSString *content)
{
    NSString *name = [NSString stringWithFormat:@"test_hbp_%d_%@.txt",
                      (int)NSProcessInfo.processInfo.processIdentifier,
                      [[NSUUID UUID] UUIDString]];
    NSString *path = [NSTemporaryDirectory()
                         stringByAppendingPathComponent:name];
    [content writeToFile:path
              atomically:YES
                encoding:NSUTF8StringEncoding
                   error:nil];
    return path;
}

static void deleteTempFile(NSString *path)
{
    [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
}

/* Return a BSD syslog timestamp string ("MMM dd HH:mm:ss") for a date that
   is secondsAgo seconds before the current time.  The result is always
   15 characters wide, matching the field width expected by HBPViolationScanner.*/
static NSString *syslogTimestamp(NSTimeInterval secondsAgo)
{
    NSDate *date = [NSDate dateWithTimeIntervalSinceNow:-secondsAgo];
    NSDateFormatter *fmt = [[NSDateFormatter alloc] init];
    [fmt setDateFormat:@"MMM dd HH:mm:ss"];
    [fmt setLocale:[NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"]];
    return [fmt stringFromDate:date];
}

/* ── HBPConfiguration tests ────────────────────────────────────────────── */

static void testConfigurationDefaults(void)
{
    HBPConfiguration *c = [HBPConfiguration defaultConfiguration];

    ASSERT("config: syslogPort is 514",
           [c.syslogPort isEqualToString:@"514"]);
    ASSERT("config: blockHours is 24",
           c.blockHours == 24);
    ASSERT("config: authlogTailLines is 500",
           c.authlogTailLines == 500);
    ASSERT("config: webViolationThreshold is 10",
           c.webViolationThreshold == 10);
    ASSERT("config: webViolationWindowHours is 1",
           c.webViolationWindowHours == 1);
    ASSERT("config: pfTableName non-empty",
           c.pfTableName.length > 0);
    ASSERT("config: blockFile non-empty",
           c.blockFile.length > 0);
    ASSERT("config: ledgerFile non-empty",
           c.ledgerFile.length > 0);
}

/* ── HBPAuthLogScanner tests ───────────────────────────────────────────── */

static void testAuthLogScannerFindsIPs(void)
{
    HBPConfiguration *config = [HBPConfiguration defaultConfiguration];
    config.whitelistIP = @"";
    config.authlogTailLines = 1000;

    NSString *log =
        @"Apr 27 10:00:01 host sshd[1]: Failed password from 1.2.3.4 port 22\n"
        @"Apr 27 10:00:02 host sshd[1]: Failed password from 5.6.7.8 port 22\n"
        @"Apr 27 10:00:03 host sshd[1]: Accepted password for user from 9.9.9.9\n";
    NSString *path = writeTempFile(log);
    config.authlogFile = path;

    HBPAuthLogScanner *scanner =
        [[HBPAuthLogScanner alloc] initWithConfiguration:config];
    NSArray *ips = [scanner scanForPattern:@"Failed password"];

    ASSERT("auth scanner: finds 2 IPs", ips.count == 2);
    ASSERT("auth scanner: contains 1.2.3.4",
           [ips containsObject:@"1.2.3.4"]);
    ASSERT("auth scanner: contains 5.6.7.8",
           [ips containsObject:@"5.6.7.8"]);
    ASSERT("auth scanner: non-matching line excluded",
           ![ips containsObject:@"9.9.9.9"]);

    deleteTempFile(path);
}

static void testAuthLogScannerRespectsWhitelist(void)
{
    HBPConfiguration *config = [HBPConfiguration defaultConfiguration];
    config.whitelistIP = @"1.2.3.4";
    config.authlogTailLines = 1000;

    NSString *log =
        @"Apr 27 10:00:01 host sshd[1]: Failed password from 1.2.3.4 port 22\n"
        @"Apr 27 10:00:02 host sshd[1]: Failed password from 5.6.7.8 port 22\n";
    NSString *path = writeTempFile(log);
    config.authlogFile = path;

    HBPAuthLogScanner *scanner =
        [[HBPAuthLogScanner alloc] initWithConfiguration:config];
    NSArray *ips = [scanner scanForPattern:@"Failed password"];

    ASSERT("auth scanner whitelist: whitelisted IP excluded",
           ![ips containsObject:@"1.2.3.4"]);
    ASSERT("auth scanner whitelist: non-whitelisted IP included",
           [ips containsObject:@"5.6.7.8"]);

    deleteTempFile(path);
}

static void testAuthLogScannerTailLines(void)
{
    HBPConfiguration *config = [HBPConfiguration defaultConfiguration];
    config.whitelistIP = @"";

    /* Three data lines — tail of 2 elements means only the last data line is
       seen (last element is the empty string after the trailing newline). */
    config.authlogTailLines = 2;

    NSString *log =
        @"Apr 27 10:00:01 host sshd[1]: Failed password from 1.2.3.4 port 22\n"
        @"Apr 27 10:00:02 host sshd[1]: Failed password from 5.6.7.8 port 22\n"
        @"Apr 27 10:00:03 host sshd[1]: Failed password from 9.9.9.9 port 22\n";
    NSString *path = writeTempFile(log);
    config.authlogFile = path;

    HBPAuthLogScanner *scanner =
        [[HBPAuthLogScanner alloc] initWithConfiguration:config];
    NSArray *ips = [scanner scanForPattern:@"Failed password"];

    ASSERT("auth scanner tail: only last line scanned", ips.count == 1);
    ASSERT("auth scanner tail: 9.9.9.9 found",
           [ips containsObject:@"9.9.9.9"]);
    ASSERT("auth scanner tail: 1.2.3.4 not found",
           ![ips containsObject:@"1.2.3.4"]);

    deleteTempFile(path);
}

static void testAuthLogScannerMissingFile(void)
{
    HBPConfiguration *config = [HBPConfiguration defaultConfiguration];
    config.authlogFile = @"/tmp/no_such_authlog_hbp_test.log";

    HBPAuthLogScanner *scanner =
        [[HBPAuthLogScanner alloc] initWithConfiguration:config];
    NSArray *ips = [scanner scanForPattern:@"Failed password"];

    ASSERT("auth scanner missing file: returns empty array", ips.count == 0);
}

/* ── HBPViolationScanner tests ─────────────────────────────────────────── */

static void testViolationScannerMeetsThreshold(void)
{
    HBPConfiguration *config = [HBPConfiguration defaultConfiguration];
    config.webViolationThreshold   = 3;
    config.webViolationWindowHours = 24;
    config.whitelistIP = @"";

    NSString *ts = syslogTimestamp(5); /* 5 seconds ago — well within 24h */

    /* 1.2.3.4 appears 3 times → at threshold → blocked */
    /* 9.9.9.9 appears 2 times → below threshold → not blocked */
    NSMutableString *log = [NSMutableString string];
    for (int i = 0; i < 3; i++)
        [log appendFormat:@"%@ host req[1]: client=1.2.3.4\n", ts];
    for (int i = 0; i < 2; i++)
        [log appendFormat:@"%@ host req[1]: client=9.9.9.9\n", ts];

    NSString *path = writeTempFile(log);
    HBPViolationScanner *scanner =
        [[HBPViolationScanner alloc] initWithConfiguration:config];
    NSArray *ips = [scanner scanLogFile:path pattern:@"client="];

    ASSERT("violation scanner threshold: IP at threshold blocked",
           [ips containsObject:@"1.2.3.4"]);
    ASSERT("violation scanner threshold: IP below threshold not blocked",
           ![ips containsObject:@"9.9.9.9"]);

    deleteTempFile(path);
}

static void testViolationScannerOldLinesIgnored(void)
{
    HBPConfiguration *config = [HBPConfiguration defaultConfiguration];
    config.webViolationThreshold   = 1;
    config.webViolationWindowHours = 1; /* 1-hour window */
    config.whitelistIP = @"";

    /* 2 hours ago — definitely outside the 1-hour window */
    NSString *oldTS = syslogTimestamp(7200);

    NSString *log = [NSString stringWithFormat:
        @"%@ host req[1]: client=2.3.4.5\n", oldTS];

    NSString *path = writeTempFile(log);
    HBPViolationScanner *scanner =
        [[HBPViolationScanner alloc] initWithConfiguration:config];
    NSArray *ips = [scanner scanLogFile:path pattern:@"client="];

    ASSERT("violation scanner window: old lines excluded", ips.count == 0);

    deleteTempFile(path);
}

static void testViolationScannerWhitelist(void)
{
    HBPConfiguration *config = [HBPConfiguration defaultConfiguration];
    config.webViolationThreshold   = 1;
    config.webViolationWindowHours = 24;
    config.whitelistIP = @"1.2.3.4";

    NSString *ts = syslogTimestamp(5);
    NSString *log = [NSString stringWithFormat:
        @"%@ host req[1]: client=1.2.3.4\n"
        @"%@ host req[1]: client=5.6.7.8\n",
        ts, ts];

    NSString *path = writeTempFile(log);
    HBPViolationScanner *scanner =
        [[HBPViolationScanner alloc] initWithConfiguration:config];
    NSArray *ips = [scanner scanLogFile:path pattern:@"client="];

    ASSERT("violation scanner whitelist: whitelisted IP excluded",
           ![ips containsObject:@"1.2.3.4"]);
    ASSERT("violation scanner whitelist: non-whitelisted IP included",
           [ips containsObject:@"5.6.7.8"]);

    deleteTempFile(path);
}

static void testViolationScannerNonMatchingLinesIgnored(void)
{
    HBPConfiguration *config = [HBPConfiguration defaultConfiguration];
    config.webViolationThreshold   = 1;
    config.webViolationWindowHours = 24;
    config.whitelistIP = @"";

    NSString *ts = syslogTimestamp(5);
    /* The line below contains an IP but does NOT match the pattern */
    NSString *log = [NSString stringWithFormat:
        @"%@ host otherservice[1]: unrelated 1.2.3.4 message\n", ts];

    NSString *path = writeTempFile(log);
    HBPViolationScanner *scanner =
        [[HBPViolationScanner alloc] initWithConfiguration:config];
    NSArray *ips = [scanner scanLogFile:path pattern:@"client="];

    ASSERT("violation scanner pattern: non-matching line excluded",
           ips.count == 0);

    deleteTempFile(path);
}

static void testViolationScannerMissingFile(void)
{
    HBPConfiguration *config = [HBPConfiguration defaultConfiguration];
    config.webViolationWindowHours = 1;

    HBPViolationScanner *scanner =
        [[HBPViolationScanner alloc] initWithConfiguration:config];
    NSArray *ips = [scanner scanLogFile:@"/tmp/no_such_violation_log.txt"
                                pattern:@"client="];

    ASSERT("violation scanner missing file: returns empty array",
           ips.count == 0);
}

/* ── HBPBlockManager tests ─────────────────────────────────────────────── */

/* Return a configuration whose block/ledger files are unique temp paths. */
static HBPConfiguration *blockManagerConfig(NSString *suffix)
{
    HBPConfiguration *config = [HBPConfiguration defaultConfiguration];
    NSString *pid = [NSString stringWithFormat:@"%d",
                     (int)NSProcessInfo.processInfo.processIdentifier];
    config.blockFile  = [NSTemporaryDirectory() stringByAppendingPathComponent:
                         [NSString stringWithFormat:@"hbp_blocks_%@_%@.txt",
                          pid, suffix]];
    config.ledgerFile = [NSTemporaryDirectory() stringByAppendingPathComponent:
                         [NSString stringWithFormat:@"hbp_ledger_%@_%@.txt",
                          pid, suffix]];
    return config;
}

static void testBlockManagerAddBlocks(void)
{
    HBPConfiguration *config = blockManagerConfig(@"add");
    HBPBlockManager *mgr =
        [[HBPBlockManager alloc] initWithConfiguration:config];

    NSInteger added = [mgr addBlocksForIPs:@[@"10.0.0.1", @"10.0.0.2"]
                                 syslogTag:@"test"];

    ASSERT("block manager add: returns count of new blocks", added == 2);

    NSString *blockContent =
        [NSString stringWithContentsOfFile:config.blockFile
                                  encoding:NSUTF8StringEncoding error:nil];
    ASSERT("block manager add: block file contains 10.0.0.1",
           [blockContent containsString:@"10.0.0.1"]);
    ASSERT("block manager add: block file contains 10.0.0.2",
           [blockContent containsString:@"10.0.0.2"]);

    NSString *ledgerContent =
        [NSString stringWithContentsOfFile:config.ledgerFile
                                  encoding:NSUTF8StringEncoding error:nil];
    ASSERT("block manager add: ledger contains 10.0.0.1",
           [ledgerContent containsString:@"10.0.0.1"]);
    ASSERT("block manager add: ledger contains 10.0.0.2",
           [ledgerContent containsString:@"10.0.0.2"]);

    deleteTempFile(config.blockFile);
    deleteTempFile(config.ledgerFile);
}

static void testBlockManagerNoDuplicates(void)
{
    HBPConfiguration *config = blockManagerConfig(@"dup");
    HBPBlockManager *mgr =
        [[HBPBlockManager alloc] initWithConfiguration:config];

    NSInteger first  = [mgr addBlocksForIPs:@[@"10.1.1.1"] syslogTag:@"t"];
    NSInteger second = [mgr addBlocksForIPs:@[@"10.1.1.1"] syslogTag:@"t"];

    ASSERT("block manager dedup: first add returns 1",  first  == 1);
    ASSERT("block manager dedup: duplicate add returns 0", second == 0);

    deleteTempFile(config.blockFile);
    deleteTempFile(config.ledgerFile);
}

static void testBlockManagerEmptyIPList(void)
{
    HBPConfiguration *config = blockManagerConfig(@"empty");
    HBPBlockManager *mgr =
        [[HBPBlockManager alloc] initWithConfiguration:config];

    NSInteger added = [mgr addBlocksForIPs:@[] syslogTag:@"t"];

    ASSERT("block manager add: empty list returns 0", added == 0);

    /* Files should not have been created */
    ASSERT("block manager add: no block file created for empty list",
           ![[NSFileManager defaultManager] fileExistsAtPath:config.blockFile]);
}

static void testBlockManagerExpireBlocks(void)
{
    HBPConfiguration *config = blockManagerConfig(@"exp");
    config.blockHours = 1;

    NSTimeInterval now = [NSDate date].timeIntervalSince1970;
    NSString *expiredEpoch = [NSString stringWithFormat:@"%.0f", now - 7200]; /* 2h ago */
    NSString *recentEpoch  = [NSString stringWithFormat:@"%.0f", now - 60];   /* 1m ago */

    NSString *ledger = [NSString stringWithFormat:
        @"10.2.2.1 %@\n10.2.2.2 %@\n", expiredEpoch, recentEpoch];
    NSString *blocks = @"10.2.2.1\n10.2.2.2\n";

    [ledger writeToFile:config.ledgerFile atomically:YES
               encoding:NSUTF8StringEncoding error:nil];
    [blocks writeToFile:config.blockFile  atomically:YES
               encoding:NSUTF8StringEncoding error:nil];

    HBPBlockManager *mgr =
        [[HBPBlockManager alloc] initWithConfiguration:config];
    NSInteger removed = [mgr expireOldBlocks];

    ASSERT("block manager expire: 1 entry removed", removed == 1);

    NSString *newBlocks =
        [NSString stringWithContentsOfFile:config.blockFile
                                  encoding:NSUTF8StringEncoding error:nil];
    ASSERT("block manager expire: expired IP removed from block file",
           ![newBlocks containsString:@"10.2.2.1"]);
    ASSERT("block manager expire: recent IP kept in block file",
           [newBlocks containsString:@"10.2.2.2"]);

    NSString *newLedger =
        [NSString stringWithContentsOfFile:config.ledgerFile
                                  encoding:NSUTF8StringEncoding error:nil];
    ASSERT("block manager expire: expired IP removed from ledger",
           ![newLedger containsString:@"10.2.2.1"]);
    ASSERT("block manager expire: recent IP kept in ledger",
           [newLedger containsString:@"10.2.2.2"]);

    deleteTempFile(config.blockFile);
    deleteTempFile(config.ledgerFile);
}

static void testBlockManagerExpireAllBlocks(void)
{
    HBPConfiguration *config = blockManagerConfig(@"expall");
    config.blockHours = 1;

    NSTimeInterval now = [NSDate date].timeIntervalSince1970;
    NSString *epoch = [NSString stringWithFormat:@"%.0f", now - 7200];

    NSString *ledger = [NSString stringWithFormat:@"10.3.3.1 %@\n", epoch];
    NSString *blocks = @"10.3.3.1\n";

    [ledger writeToFile:config.ledgerFile atomically:YES
               encoding:NSUTF8StringEncoding error:nil];
    [blocks writeToFile:config.blockFile  atomically:YES
               encoding:NSUTF8StringEncoding error:nil];

    HBPBlockManager *mgr =
        [[HBPBlockManager alloc] initWithConfiguration:config];
    NSInteger removed = [mgr expireOldBlocks];

    ASSERT("block manager expire all: 1 entry removed", removed == 1);

    NSString *newBlocks =
        [NSString stringWithContentsOfFile:config.blockFile
                                  encoding:NSUTF8StringEncoding error:nil];
    ASSERT("block manager expire all: block file empty",
           newBlocks.length == 0);

    deleteTempFile(config.blockFile);
    deleteTempFile(config.ledgerFile);
}

static void testBlockManagerExpireMissingLedger(void)
{
    HBPConfiguration *config = blockManagerConfig(@"noleder");
    config.blockHours = 1;
    /* ledgerFile intentionally does not exist */

    HBPBlockManager *mgr =
        [[HBPBlockManager alloc] initWithConfiguration:config];
    NSInteger removed = [mgr expireOldBlocks];

    ASSERT("block manager expire: missing ledger returns 0", removed == 0);
}

/* ── Entry point ───────────────────────────────────────────────────────── */

int main(int argc, const char *argv[])
{
    testConfigurationDefaults();

    testAuthLogScannerFindsIPs();
    testAuthLogScannerRespectsWhitelist();
    testAuthLogScannerTailLines();
    testAuthLogScannerMissingFile();

    testViolationScannerMeetsThreshold();
    testViolationScannerOldLinesIgnored();
    testViolationScannerWhitelist();
    testViolationScannerNonMatchingLinesIgnored();
    testViolationScannerMissingFile();

    testBlockManagerAddBlocks();
    testBlockManagerNoDuplicates();
    testBlockManagerEmptyIPList();
    testBlockManagerExpireBlocks();
    testBlockManagerExpireAllBlocks();
    testBlockManagerExpireMissingLedger();

    fprintf(stdout, "\n%d passed, %d failed\n", g_passed, g_failed);
    return g_failed > 0 ? 1 : 0;
}
