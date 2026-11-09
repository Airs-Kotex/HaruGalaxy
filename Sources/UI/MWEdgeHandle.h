// SPDX-License-Identifier: Apache-2.0
#import <UIKit/UIKit.h>
@interface MWEdgeHandle : UIControl
@property(nonatomic,copy) void (^activationHandler)(void);
@property(nonatomic,copy) void (^movementBeganHandler)(void);
@property(nonatomic,copy) void (^positionChangedHandler)(void);
@property(nonatomic) NSUInteger minimizedCount;
@property(nonatomic) BOOL panelOpen;
- (void)applyViewport:(CGRect)viewport;
@end
