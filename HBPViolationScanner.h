// HBPViolationScanner.h
// Reads a syslog-format log file, parses the BSD syslog timestamp on each
// line, counts how many times each attacker IP appears within a rolling time
// window, and returns every IP whose count meets or exceeds a configurable
// threshold.
//
// This is used to integrate OBJC-allowlisting and OBJC-slowlorisdetector
// violations into pf-blocker:
//
//   • --monitor-allowlist-violations scans /var/log/authlog for lines logged
//     by request_validator and blocks IPs that exceed the threshold.
//
//   • --monitor-slowloris-violations scans /var/log/daemon for lines logged
//     by SlowlorisMonitor and brings those blocks into the HBP ledger so that
//     --expire-blocks can manage their lifetime alongside SSH blocks.

#import <Foundation/Foundation.h>
#import "HBPConfiguration.h"

NS_ASSUME_NONNULL_BEGIN

@interface HBPViolationScanner : NSObject

- (instancetype)initWithConfiguration:(HBPConfiguration *)config;

/// Scan @a logFile for lines matching @a pattern.  For each matching line
/// the BSD syslog timestamp is parsed; lines older than
/// config.webViolationWindowHours are ignored.  IPv4 addresses are extracted
/// from the remaining lines and counted per IP.  Every IP whose count
/// meets or exceeds config.webViolationThreshold is included in the result.
///
/// @param logFile   Absolute path to the syslog file to read.
/// @param pattern   ICU regular expression identifying an attack log line.
/// @return          A (possibly empty) array of NSString IPv4 addresses.
- (NSArray<NSString *> *)scanLogFile:(NSString *)logFile
                             pattern:(NSString *)pattern;

@end

NS_ASSUME_NONNULL_END
