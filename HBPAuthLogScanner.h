// HBPAuthLogScanner.h
// Reads /var/log/authlog (or a configured alternative), keeps the last N
// lines, and extracts unique attacker IPv4 addresses from lines that match
// a given pattern.

#import <Foundation/Foundation.h>
#import "HBPConfiguration.h"

NS_ASSUME_NONNULL_BEGIN

@interface HBPAuthLogScanner : NSObject

- (instancetype)initWithConfiguration:(HBPConfiguration *)config;

/// Scan the authlog for lines matching @a pattern and return the set of
/// unique IPv4 addresses found in those lines (excluding the whitelist IP).
///
/// @param pattern  An ICU regular expression matched against each log line.
/// @return         A (possibly empty) array of NSString IPv4 addresses.
- (NSArray<NSString *> *)scanForPattern:(NSString *)pattern;

@end

NS_ASSUME_NONNULL_END
