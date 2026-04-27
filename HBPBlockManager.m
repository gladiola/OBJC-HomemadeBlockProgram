// HBPBlockManager.m

#import "HBPBlockManager.h"
#include <stdio.h>    /* rename(2) */
#include <errno.h>    /* errno, strerror() */

@implementation HBPBlockManager {
    HBPConfiguration *_config;
}

- (instancetype)initWithConfiguration:(HBPConfiguration *)config {
    self = [super init];
    if (self) {
        _config = config;
    }
    return self;
}

// ---------------------------------------------------------------------------
// Private helpers
// ---------------------------------------------------------------------------

/// Return the set of IPs currently in the block file.
- (NSMutableSet<NSString *> *)loadBlockedIPs {
    NSString *content = [NSString stringWithContentsOfFile:_config.blockFile
                                                  encoding:NSUTF8StringEncoding
                                                     error:nil];
    NSMutableSet<NSString *> *set = [NSMutableSet set];
    if (!content) { return set; }

    for (NSString *line in [content componentsSeparatedByString:@"\n"]) {
        NSString *ip = [line stringByTrimmingCharactersInSet:
                        NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if (ip.length > 0) { [set addObject:ip]; }
    }
    return set;
}

/// Append @a text (which should end with "\n") to the file at @a path.
/// Creates the file if it does not yet exist.
- (void)appendText:(NSString *)text toFile:(NSString *)path {
    NSData *data = [text dataUsingEncoding:NSUTF8StringEncoding];
    if (!data) { return; }

    NSFileManager *fm = NSFileManager.defaultManager;
    if (![fm fileExistsAtPath:path]) {
        [fm createFileAtPath:path contents:data attributes:nil];
        return;
    }

    NSFileHandle *fh = [NSFileHandle fileHandleForWritingAtPath:path];
    if (!fh) {
        NSLog(@"pf-blocker: cannot open %@ for writing: %s", path, strerror(errno));
        return;
    }
    [fh seekToEndOfFile];
    [fh writeData:data];
    [fh closeFile];
}

/// Send a single message to the remote syslog server via logger(1).
/// Mirrors:  logger -n HOST -P PORT -p PRIORITY MESSAGE
- (void)logToRemoteSyslog:(NSString *)message priority:(NSString *)priority {
    NSTask *task = [[NSTask alloc] init];
    task.launchPath = @"/usr/bin/logger";
    task.arguments  = @[ @"-n", _config.syslogHost,
                         @"-P", _config.syslogPort,
                         @"-p", priority,
                         message ];
    NSError *err = nil;
    if (![task launchAndReturnError:&err]) {
        NSLog(@"pf-blocker: logger failed: %@", err);
    } else {
        [task waitUntilExit];
    }
}

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

- (NSInteger)addBlocksForIPs:(NSArray<NSString *> *)ips
                   syslogTag:(NSString *)tag {
    if (ips.count == 0) { return 0; }

    NSMutableSet<NSString *> *blocked = [self loadBlockedIPs];
    NSTimeInterval now = NSDate.date.timeIntervalSince1970;
    NSString *nowStr = [NSString stringWithFormat:@"%.0f", now];
    NSInteger newBlocks = 0;

    for (NSString *ip in ips) {
        if ([blocked containsObject:ip]) { continue; }

        // Append to block file.
        [self appendText:[ip stringByAppendingString:@"\n"]
                  toFile:_config.blockFile];

        // Append to ledger:  "IP EPOCH\n"
        [self appendText:[NSString stringWithFormat:@"%@ %@\n", ip, nowStr]
                  toFile:_config.ledgerFile];

        // Remote syslog notification.
        NSString *msg = [NSString stringWithFormat:@"pf-blocker: %@ %@", tag, ip];
        [self logToRemoteSyslog:msg priority:@"auth.warning"];

        [blocked addObject:ip];
        newBlocks++;
    }

    return newBlocks;
}

- (NSInteger)expireOldBlocks {
    NSError *err = nil;
    NSString *ledgerContent = [NSString stringWithContentsOfFile:_config.ledgerFile
                                                        encoding:NSUTF8StringEncoding
                                                           error:&err];
    if (!ledgerContent) {
        // Nothing to do when the ledger does not exist yet.
        return 0;
    }

    NSTimeInterval now       = NSDate.date.timeIntervalSince1970;
    NSTimeInterval threshold = _config.blockHours * 3600.0;

    NSMutableArray<NSString *> *remaining = [NSMutableArray array];
    NSMutableArray<NSString *> *expired   = [NSMutableArray array];

    for (NSString *line in [ledgerContent componentsSeparatedByString:@"\n"]) {
        NSString *trimmed = [line stringByTrimmingCharactersInSet:
                             NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if (trimmed.length == 0) { continue; }

        // Each ledger line is "IP EPOCH_SECONDS".
        NSArray<NSString *> *parts = [trimmed componentsSeparatedByString:@" "];
        if (parts.count < 2) { continue; }

        NSString *ip          = parts[0];
        NSTimeInterval ts     = [parts[1] doubleValue];
        NSTimeInterval age    = now - ts;

        if (age >= threshold) {
            [expired addObject:ip];
        } else {
            [remaining addObject:trimmed];
        }
    }

    if (expired.count == 0) { return 0; }

    // Build a new block file that excludes all expired IPs.
    NSString *blockContent = [NSString stringWithContentsOfFile:_config.blockFile
                                                       encoding:NSUTF8StringEncoding
                                                          error:nil] ?: @"";
    NSSet<NSString *> *expiredSet = [NSSet setWithArray:expired];
    NSMutableArray<NSString *> *newBlockLines = [NSMutableArray array];

    for (NSString *line in [blockContent componentsSeparatedByString:@"\n"]) {
        NSString *ip = [line stringByTrimmingCharactersInSet:
                        NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if (ip.length > 0 && ![expiredSet containsObject:ip]) {
            [newBlockLines addObject:ip];
        }
    }

    // Write to temp files in the same directory so rename(2) is atomic.
    NSString *dir      = [_config.blockFile stringByDeletingLastPathComponent];
    NSString *pid      = [NSString stringWithFormat:@"%d",
                          (int)NSProcessInfo.processInfo.processIdentifier];
    NSString *tmpBlock  = [dir stringByAppendingPathComponent:
                           [@"arbitraryBlocks.tmp." stringByAppendingString:pid]];
    NSString *tmpLedger = [dir stringByAppendingPathComponent:
                           [@"blockLedger.tmp." stringByAppendingString:pid]];

    NSString *newBlockContent =
        newBlockLines.count > 0
        ? [[newBlockLines componentsJoinedByString:@"\n"] stringByAppendingString:@"\n"]
        : @"";
    NSString *newLedgerContent =
        remaining.count > 0
        ? [[remaining componentsJoinedByString:@"\n"] stringByAppendingString:@"\n"]
        : @"";

    NSError *writeErr = nil;
    if (![newBlockContent writeToFile:tmpBlock
                           atomically:NO
                             encoding:NSUTF8StringEncoding
                                error:&writeErr]) {
        NSLog(@"pf-blocker: cannot write temp block file: %@", writeErr);
        return 0;
    }
    if (![newLedgerContent writeToFile:tmpLedger
                            atomically:NO
                              encoding:NSUTF8StringEncoding
                                 error:&writeErr]) {
        NSLog(@"pf-blocker: cannot write temp ledger file: %@", writeErr);
        [[NSFileManager defaultManager] removeItemAtPath:tmpBlock error:nil];
        return 0;
    }

    // rename(2) atomically replaces the destination on the same filesystem.
    if (rename(tmpBlock.fileSystemRepresentation,
               _config.blockFile.fileSystemRepresentation) != 0) {
        perror("pf-blocker: rename block file");
        [[NSFileManager defaultManager] removeItemAtPath:tmpBlock  error:nil];
        [[NSFileManager defaultManager] removeItemAtPath:tmpLedger error:nil];
        return 0;
    }
    if (rename(tmpLedger.fileSystemRepresentation,
               _config.ledgerFile.fileSystemRepresentation) != 0) {
        perror("pf-blocker: rename ledger file");
        [[NSFileManager defaultManager] removeItemAtPath:tmpLedger error:nil];
        return 0;
    }

    // Log each expiry to the remote syslog server.
    for (NSString *ip in expired) {
        NSString *msg = [NSString stringWithFormat:
                         @"pf-blocker: expired block for %@ after %ldh",
                         ip, (long)_config.blockHours];
        [self logToRemoteSyslog:msg priority:@"auth.info"];
    }

    return (NSInteger)expired.count;
}

- (void)reloadPFTable {
    NSTask *task = [[NSTask alloc] init];
    task.launchPath = @"/sbin/pfctl";
    task.arguments  = @[ @"-t", _config.pfTableName,
                         @"-T", @"replace",
                         @"-f", _config.blockFile ];
    NSError *err = nil;
    if (![task launchAndReturnError:&err]) {
        NSLog(@"pf-blocker: pfctl failed: %@", err);
    } else {
        [task waitUntilExit];
    }
}

@end
