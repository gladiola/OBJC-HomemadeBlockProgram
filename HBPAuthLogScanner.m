// HBPAuthLogScanner.m

#import "HBPAuthLogScanner.h"

// IPv4 address pattern — matches the same set of addresses as the grep -E -o
// expression used in the original shell scripts.
static NSString * const kIPv4Pattern =
    @"(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)"
    @"(?:\\.(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)){3}";

@implementation HBPAuthLogScanner {
    HBPConfiguration *_config;
    NSRegularExpression *_ipRegex;
}

- (instancetype)initWithConfiguration:(HBPConfiguration *)config {
    self = [super init];
    if (self) {
        _config = config;

        NSError *err = nil;
        _ipRegex = [NSRegularExpression regularExpressionWithPattern:kIPv4Pattern
                                                             options:0
                                                               error:&err];
        if (!_ipRegex) {
            NSLog(@"pf-blocker: internal error building IPv4 regex: %@", err);
        }
    }
    return self;
}

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

- (NSArray<NSString *> *)scanForPattern:(NSString *)pattern {
    if (!_ipRegex) { return @[]; }

    // 1. Read the auth log.
    NSError *err = nil;
    NSString *content = [NSString stringWithContentsOfFile:_config.authlogFile
                                                  encoding:NSUTF8StringEncoding
                                                     error:&err];
    if (!content) {
        NSLog(@"pf-blocker: cannot read %@: %@", _config.authlogFile, err);
        return @[];
    }

    // 2. Take the last authlogTailLines lines (mirrors `tail -n N`).
    NSArray<NSString *> *allLines = [content componentsSeparatedByString:@"\n"];
    NSArray<NSString *> *lines;
    NSInteger tail = _config.authlogTailLines;
    if ((NSInteger)allLines.count > tail) {
        lines = [allLines subarrayWithRange:
                 NSMakeRange(allLines.count - (NSUInteger)tail, (NSUInteger)tail)];
    } else {
        lines = allLines;
    }

    // 3. Compile the caller's pattern.
    NSRegularExpression *attackRegex =
        [NSRegularExpression regularExpressionWithPattern:pattern
                                                  options:0
                                                    error:&err];
    if (!attackRegex) {
        NSLog(@"pf-blocker: invalid pattern \"%@\": %@", pattern, err);
        return @[];
    }

    // 4. Filter lines, skip the whitelist address, and collect IPs.
    NSMutableSet<NSString *> *found = [NSMutableSet set];

    for (NSString *line in lines) {
        if (line.length == 0) { continue; }

        // Skip lines that don't contain the attack signature.
        if ([attackRegex numberOfMatchesInString:line
                                         options:0
                                           range:NSMakeRange(0, line.length)] == 0) {
            continue;
        }

        // Skip lines that mention the whitelisted address.
        if (_config.whitelistIP.length > 0 &&
            [line rangeOfString:_config.whitelistIP].location != NSNotFound) {
            continue;
        }

        // Extract all IPv4 addresses from the line.
        NSArray<NSTextCheckingResult *> *matches =
            [_ipRegex matchesInString:line options:0 range:NSMakeRange(0, line.length)];
        for (NSTextCheckingResult *m in matches) {
            [found addObject:[line substringWithRange:m.range]];
        }
    }

    return found.allObjects;
}

@end
