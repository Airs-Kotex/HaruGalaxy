// SPDX-License-Identifier: Apache-2.0
#import <UIKit/UIKit.h>
@interface MWRootWindowAdapter : NSObject
@property(nonatomic,weak) UIWindow *overlayWindow;
- (BOOL)attachToRootView:(UIView *)root error:(NSError **)error;
- (void)refresh;
- (void)detach;
@end
