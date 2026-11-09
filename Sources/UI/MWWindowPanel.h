// SPDX-License-Identifier: Apache-2.0
#import <UIKit/UIKit.h>
@class MWWindowView;
@interface MWWindowPanel : UIVisualEffectView
@property(nonatomic,copy) void (^openApplicationHandler)(void);
@property(nonatomic,copy) void (^settingsHandler)(void);
@property(nonatomic,copy) void (^activateHandler)(NSString *bundle);
@property(nonatomic,copy) void (^minimizeHandler)(NSString *bundle);
@property(nonatomic,copy) void (^fullscreenHandler)(NSString *bundle);
@property(nonatomic,copy) void (^closeHandler)(NSString *bundle);
@property(nonatomic,readonly) NSUInteger createdRowCount;
- (void)updateWindows:(NSArray<MWWindowView *> *)windows;
- (void)placeNearAnchor:(CGRect)anchor inBounds:(CGRect)bounds;
@end
