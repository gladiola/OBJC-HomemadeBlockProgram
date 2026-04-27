// HBPViolationScanner.m

#import "HBPViolationScanner.h"

// Matches a valid IPv4 address — same pattern used in HBPAuthLogScanner.
static NSString * const kIPv4Pattern =
    @"(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)"
    @"(?:\\.(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)){3}";

// BSD syslog timestamp field width: "Apr 27 15:30:45" = 15 characters.
static const NSUInteger kSyslogTimestampLength = 15;

// One day in seconds, used for year-rollover detection.
static const NSTimeInterval kSecondsPerDay = 24 * 60 * 60;

@implementation HBPViolationScanner {
    HBPConfiguration    *_config;
    NSRegularExpression *_ipRegex;
    NSDateFormatter     *_dateFormatter;
    NSCalendar          *_calendar;
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

        // BSD syslog timestamps look like "Apr 27 15:30:45" or "Apr  7 15:30:45"
        // (single-digit days are space-padded).  We normalize double-spaces to a
        // single space before parsing, so "d" (1–2 digit day) works for both.
        _dateFormatter = [[NSDateFormatter alloc] init];
        [_dateFormatter setDateFormat:@"yyyy MMM d HH:mm:ss"];
        [_dateFormatter setLocale:
            [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"]];

        _calendar = [NSCalendar
            calendarWithIdentifier:NSCalendarIdentifierGregorian];
    }
    return self;
}

// ---------------------------------------------------------------------------
// Private helpers
// ---------------------------------------------------------------------------

/// Parse the BSD syslog timestamp at the beginning of @a line.
/// Returns nil when the line is too short or the timestamp is not recognised.
- (nullable NSDate *)parseSyslogTimestamp:(NSString *)line {
    if (line.length < kSyslogTimestampLength) { return nil; }

    // Extract the 15-character timestamp prefix.
    NSString *raw = [line substringToIndex:kSyslogTimestampLength];

    // Normalise space-padded single-digit days ("Apr  7 …" → "Apr 7 …").
    NSString *normalised =
        [raw stringByReplacingOccurrencesOfString:@"  " withString:@" "];

    // Prepend the current year so NSDateFormatter can build a full NSDate.
    NSInteger year =
        [[_calendar components:NSCalendarUnitYear
                      fromDate:[NSDate date]] year];
    NSString *fullTS =
        [NSString stringWithFormat:@"%ld %@", (long)year, normalised];

    NSDate *date = [_dateFormatter dateFromString:fullTS];
    if (!date) { return nil; }

    // Guard against year-rollover: if the resulting date is more than one day
    // in the future the log entry must be from the previous year.
    if ([date timeIntervalSinceNow] > kSecondsPerDay) {
        fullTS = [NSString stringWithFormat:@"%ld %@",
                  (long)(year - 1), normalised];
        date = [_dateFormatter dateFromString:fullTS];
    }
    return date;
}

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

- (NSArray<NSString *> *)scanLogFile:(NSString *)logFile
                             pattern:(NSString *)pattern {
    if (!_ipRegex) { return @[]; }

    // 1. Read the log file.
    NSError *err = nil;
    NSString *content = [NSString stringWithContentsOfFile:logFile
                                                  encoding:NSUTF8StringEncoding
                                                     error:&err];
    if (!content) {
        NSLog(@"pf-blocker: cannot read %@: %@", logFile, err);
        return @[];
    }

    // 2. Compile the caller's attack-signature pattern.
    NSRegularExpression *attackRegex =
        [NSRegularExpression regularExpressionWithPattern:pattern
                                                  options:0
                                                    error:&err];
    if (!attackRegex) {
        NSLog(@"pf-blocker: invalid pattern \"%@\": %@", pattern, err);
        return @[];
    }

    NSDate *now = [NSDate date];
    NSTimeInterval windowSeconds =
        (NSTimeInterval)_config.webViolationWindowHours * 3600.0;

    // 3. Walk every line, filter by signature and timestamp, count IPs.
    NSMutableDictionary<NSString *, NSNumber *> *counts =
        [NSMutableDictionary dictionary];

    for (NSString *line in [content componentsSeparatedByString:@"\n"]) {
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

        // Skip lines outside the rolling time window.
        NSDate *ts = [self parseSyslogTimestamp:line];
        if (!ts) { continue; }
        if ([now timeIntervalSinceDate:ts] > windowSeconds) { continue; }

        // Extract every IPv4 address from the line and increment its counter.
        NSArray<NSTextCheckingResult *> *matches =
            [_ipRegex matchesInString:line options:0
                                range:NSMakeRange(0, line.length)];
        for (NSTextCheckingResult *m in matches) {
            NSString *ip = [line substringWithRange:m.range];
            counts[ip] = @([counts[ip] integerValue] + 1);
        }
    }

    // 4. Return IPs whose count meets or exceeds the threshold.
    NSMutableArray<NSString *> *result = [NSMutableArray array];
    for (NSString *ip in counts) {
        if ([counts[ip] integerValue] >= _config.webViolationThreshold) {
            [result addObject:ip];
        }
    }
    return result;
}

@end
