// SPDX-License-Identifier: Apache-2.0
#import "MWGlassSurface.h"
@class MWWindowView;
@interface MWWindowPanel : MWGlassSurface
@property(nonatomic,copy) void (^openApplicationHandler)(void);
@property(nonatomic,copy) void (^settingsHandler)(void);
@property(nonatomic,copy) void (^parkingSettingsHandler)(void);
@property(nonatomic,copy) void (^openOriginalHandler)(NSString *bundle);
@property(nonatomic,copy) void (^compatibleCanvasHandler)(NSString *bundle,BOOL enabled);
@property(nonatomic,copy) void (^parkHandler)(NSString *bundle);
@property(nonatomic,copy) void (^activateHandler)(NSString *bundle);
@property(nonatomic,copy) void (^minimizeHandler)(NSString *bundle);
@property(nonatomic,copy) void (^fullscreenHandler)(NSString *bundle);
@property(nonatomic,copy) void (^closeHandler)(NSString *bundle);
@property(nonatomic,readonly) NSUInteger createdRowCount;
- (void)updateWindows:(NSArray<MWWindowView *> *)windows;
- (void)placeNearAnchor:(CGRect)anchor inBounds:(CGRect)bounds;
@end
