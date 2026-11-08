// SPDX-License-Identifier: Apache-2.0
#import <UIKit/UIKit.h>
@interface MWEdgeHandle : UIControl
@property(nonatomic,copy) void (^activationHandler)(void);
@property(nonatomic,copy) void (^settingsHandler)(void);
- (void)applyViewport:(CGRect)viewport;
@end
