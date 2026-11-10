// SPDX-License-Identifier: Apache-2.0
#import <UIKit/UIKit.h>
FOUNDATION_EXPORT NSString *const MWDeviceOrientationDidChangeNotification;
@interface MWDeviceOrientation : NSObject
@property(nonatomic,readonly) UIInterfaceOrientation orientation;
- (void)start;
- (void)stop;
- (void)setTrackingEnabled:(BOOL)enabled;
- (UIInterfaceOrientation)orientationForHost:(UIInterfaceOrientation)host floating:(BOOL)floating;
- (NSDictionary *)diagnosticSnapshot;
@end
