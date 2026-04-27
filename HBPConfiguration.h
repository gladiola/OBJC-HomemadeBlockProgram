// HBPConfiguration.h
// pf-blocker — Objective-C replacement for the OpenBSD homemade block scripts.
//
// Edit the values in +defaultConfiguration to match your environment before
// building, or allocate an HBPConfiguration and set the properties at runtime.

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface HBPConfiguration : NSObject

// ---------------------------------------------------------------------------
// Remote syslog settings
// ---------------------------------------------------------------------------

/// Hostname or IP address of the remote syslog server.
@property (nonatomic, copy) NSString *syslogHost;

/// UDP port of the remote syslog server (standard is 514).
@property (nonatomic, copy) NSString *syslogPort;

// ---------------------------------------------------------------------------
// Block-expiry settings
// ---------------------------------------------------------------------------

/// Number of hours a block stays in effect before expireBlocks removes it.
@property (nonatomic, assign) NSInteger blockHours;

// ---------------------------------------------------------------------------
// File paths
// ---------------------------------------------------------------------------

/// pf block table text file — loaded into pf with pfctl.
@property (nonatomic, copy) NSString *blockFile;

/// Ledger file — one "IP EPOCH" line per blocked address.
@property (nonatomic, copy) NSString *ledgerFile;

/// OpenBSD authentication log file.
@property (nonatomic, copy) NSString *authlogFile;

// ---------------------------------------------------------------------------
// Firewall settings
// ---------------------------------------------------------------------------

/// Name of the pf table that holds the block list.
@property (nonatomic, copy) NSString *pfTableName;

// ---------------------------------------------------------------------------
// Scanning settings
// ---------------------------------------------------------------------------

/// How many lines to read from the tail of authlog each run.
@property (nonatomic, assign) NSInteger authlogTailLines;

/// IP address to never block (your trusted management address).
/// Replace "www.xxx.yyy.zzz" with your real IP before deploying.
@property (nonatomic, copy) NSString *whitelistIP;

// ---------------------------------------------------------------------------
// Factory
// ---------------------------------------------------------------------------

/// Returns a configuration pre-filled with the same defaults that the
/// shell scripts used.  Edit these values to match your site.
+ (instancetype)defaultConfiguration;

// ---------------------------------------------------------------------------
// Validation
// ---------------------------------------------------------------------------

/// Emit NSLog warnings for any settings that still contain placeholder values.
/// Call this once at program startup before performing any blocking actions.
- (void)warnAboutPlaceholders;

@end

NS_ASSUME_NONNULL_END
