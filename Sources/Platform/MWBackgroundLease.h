// SPDX-License-Identifier: Apache-2.0
#import <Foundation/Foundation.h>
FOUNDATION_EXPORT NSString *const MWBackgroundLeaseDidChangeNotification;
@interface MWBackgroundLease : NSObject
@property(nonatomic,readonly) BOOL valid;
- (BOOL)acquireWithError:(NSError **)error;
// Call only with the PID of a process already resolved for an owned session.
- (BOOL)acquireForProcess:(pid_t)pid name:(NSString *)name error:(NSError **)error;
- (void)invalidate;
@end
