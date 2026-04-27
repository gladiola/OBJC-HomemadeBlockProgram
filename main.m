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
//   pf-blocker --monitor-allowlist-violations
//       Block IPs that have violated the CGI allowlist
//       (OBJC-allowlisting / request_validator) 10+ times in the past hour.
//       Reads /var/log/authlog.
//
//   pf-blocker --monitor-slowloris-violations
//       Bring IPs already flagged by the Slowloris detector
//       (OBJC-slowlorisdetector / SlowlorisMonitor) into the HBP ledger so
//       that --expire-blocks can manage their lifetime.
//       Reads /var/log/daemon.
//
//   pf-blocker --expire-blocks
//       Remove blocks older than BLOCK_HOURS from the block file and ledger.
//
// All modes are designed to be invoked from root's crontab, for example:
//
//   */5 * * * * /usr/local/sbin/pf-blocker --monitor-invalid-user
//   */5 * * * * /usr/local/sbin/pf-blocker --monitor-disconnect
//   */5 * * * * /usr/local/sbin/pf-blocker --monitor-allowlist-violations
//   */5 * * * * /usr/local/sbin/pf-blocker --monitor-slowloris-violations
//   0   * * * * /usr/local/sbin/pf-blocker --expire-blocks

#import <Foundation/Foundation.h>
#import "HBPConfiguration.h"
#import "HBPAuthLogScanner.h"
#import "HBPBlockManager.h"
#import "HBPViolationScanner.h"

static void printUsage(const char *prog) {
    fprintf(stderr,
        "Usage: %s [--monitor-invalid-user | --monitor-disconnect |\n"
        "          --monitor-allowlist-violations |\n"
        "          --monitor-slowloris-violations | --expire-blocks]\n"
        "\n"
        "  --monitor-invalid-user           Block IPs from sshd 'Invalid user' entries\n"
        "  --monitor-disconnect             Block IPs from sshd 'Received disconnect' entries\n"
        "  --monitor-allowlist-violations   Block IPs with 10+ CGI allowlist violations in 1h\n"
        "  --monitor-slowloris-violations   Add Slowloris-blocked IPs to the HBP ledger\n"
        "  --expire-blocks                  Remove blocks older than BLOCK_HOURS\n",
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

        } else if ([mode isEqualToString:@"--monitor-allowlist-violations"]) {
            HBPViolationScanner *scanner =
                [[HBPViolationScanner alloc] initWithConfiguration:config];
            NSArray<NSString *> *ips =
                [scanner scanLogFile:config.authlogFile
                             pattern:@"request_validator.*client="];
            NSInteger n = [manager addBlocksForIPs:ips
                                         syslogTag:@"blocked CGI allowlist violator"];
            if (n > 0) {
                [manager reloadPFTable];
            }

        } else if ([mode isEqualToString:@"--monitor-slowloris-violations"]) {
            HBPViolationScanner *scanner =
                [[HBPViolationScanner alloc] initWithConfiguration:config];
            NSArray<NSString *> *ips =
                [scanner scanLogFile:@"/var/log/daemon"
                             pattern:@"SlowlorisMonitor.*Suspicious IP"];
            NSInteger n = [manager addBlocksForIPs:ips
                                         syslogTag:@"blocked Slowloris attacker"];
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
