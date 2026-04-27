// main.m
// pf-blocker — Objective-C replacement for the OpenBSD homemade block scripts.
//
// Usage:
//   pf-blocker --monitor-invalid-user
//       Block IPs seen in "Invalid user" SSH log entries.
//
//   pf-blocker --monitor-disconnect
//       Block IPs seen in "Received disconnect from" SSH log entries.
//
//   pf-blocker --expire-blocks
//       Remove blocks older than BLOCK_HOURS from the block file and ledger.
//
// All three modes are designed to be invoked from root's crontab, for
// example:
//
//   */5 * * * * /usr/local/sbin/pf-blocker --monitor-invalid-user
//   */5 * * * * /usr/local/sbin/pf-blocker --monitor-disconnect
//   0   * * * * /usr/local/sbin/pf-blocker --expire-blocks

#import <Foundation/Foundation.h>
#import "HBPConfiguration.h"
#import "HBPAuthLogScanner.h"
#import "HBPBlockManager.h"

static void printUsage(const char *prog) {
    fprintf(stderr,
        "Usage: %s [--monitor-invalid-user | --monitor-disconnect | --expire-blocks]\n"
        "\n"
        "  --monitor-invalid-user    Block IPs from sshd 'Invalid user' entries\n"
        "  --monitor-disconnect      Block IPs from sshd 'Received disconnect' entries\n"
        "  --expire-blocks           Remove blocks older than BLOCK_HOURS\n",
        prog);
}

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        if (argc < 2) {
            printUsage(argv[0]);
            return 1;
        }

        NSString *mode = [NSString stringWithUTF8String:argv[1]];

        HBPConfiguration *config  = [HBPConfiguration defaultConfiguration];
        [config warnAboutPlaceholders];
        HBPBlockManager  *manager = [[HBPBlockManager alloc] initWithConfiguration:config];

        if ([mode isEqualToString:@"--monitor-invalid-user"]) {
            HBPAuthLogScanner *scanner =
                [[HBPAuthLogScanner alloc] initWithConfiguration:config];
            NSArray<NSString *> *ips =
                [scanner scanForPattern:@"sshd.*Invalid user"];
            NSInteger n = [manager addBlocksForIPs:ips
                                         syslogTag:@"blocked SSH invalid-user attacker"];
            if (n > 0) {
                [manager reloadPFTable];
            }

        } else if ([mode isEqualToString:@"--monitor-disconnect"]) {
            HBPAuthLogScanner *scanner =
                [[HBPAuthLogScanner alloc] initWithConfiguration:config];
            NSArray<NSString *> *ips =
                [scanner scanForPattern:@"sshd.*Received disconnect from"];
            NSInteger n = [manager addBlocksForIPs:ips
                                         syslogTag:@"blocked SSH disconnect attacker"];
            if (n > 0) {
                [manager reloadPFTable];
            }

        } else if ([mode isEqualToString:@"--expire-blocks"]) {
            NSInteger n = [manager expireOldBlocks];
            if (n > 0) {
                [manager reloadPFTable];
            }

        } else {
            printUsage(argv[0]);
            return 1;
        }
    }
    return 0;
}
