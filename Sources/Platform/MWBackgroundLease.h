// SPDX-License-Identifier: Apache-2.0
#import <Foundation/Foundation.h>
@interface MWBackgroundLease : NSObject
@property(nonatomic,readonly) BOOL valid;
- (BOOL)acquireWithError:(NSError **)error;
- (void)invalidate;
@end
