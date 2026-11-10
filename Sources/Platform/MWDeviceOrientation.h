// SPDX-License-Identifier: Apache-2.0
#import <UIKit/UIKit.h>
FOUNDATION_EXPORT NSString *const MWDeviceOrientationDidChangeNotification;
@interface MWDeviceOrientation : NSObject
@property(nonatomic,readonly) UIInterfaceOrientation orientation;
- (void)start;
- (void)stop;
@end
