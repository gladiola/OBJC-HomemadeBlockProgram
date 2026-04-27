// HBPBlockManager.h
// Manages the pf block file and the block ledger.
//
//  • addBlocksForIPs:syslogTag:  — appends new IPs to the block file and
//    ledger, sends a remote syslog message for each one, and returns the
//    count of newly added entries.
//
//  • expireOldBlocks             — reads the ledger, removes entries that
//    are older than config.blockHours, atomically rewrites both files, and
//    returns the count of removed entries.
//
//  • reloadPFTable               — runs pfctl to load the updated block file
//    into the live pf table.

#import <Foundation/Foundation.h>
#import "HBPConfiguration.h"

NS_ASSUME_NONNULL_BEGIN

@interface HBPBlockManager : NSObject

- (instancetype)initWithConfiguration:(HBPConfiguration *)config;

/// Append any IP in @a ips that is not already in the block file.
/// Each new block is logged to the remote syslog server.
/// @return  Number of IPs newly added to the block file.
- (NSInteger)addBlocksForIPs:(NSArray<NSString *> *)ips
                   syslogTag:(NSString *)tag;

/// Remove ledger entries whose age exceeds config.blockHours, rewrite both
/// the ledger and block files atomically, and log each removal.
/// @return  Number of blocks that were removed.
- (NSInteger)expireOldBlocks;

/// Reload the live pf table from the block file via pfctl.
- (void)reloadPFTable;

@end

NS_ASSUME_NONNULL_END
