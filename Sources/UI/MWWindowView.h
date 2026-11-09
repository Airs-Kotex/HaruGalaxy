// SPDX-License-Identifier: Apache-2.0
#import <UIKit/UIKit.h>
#import "../Core/MWWindowModel.h"
#import "../Platform/MWApplicationCatalog.h"
#import "../Platform/MWSceneSession.h"
@interface MWWindowView : UIView
@property(nonatomic,strong,readonly) MWApplication *application;
@property(nonatomic,strong,readonly) MWSceneSession *session;
@property(nonatomic,readonly) MWWindowModel model;
@property(nonatomic,copy) void (^activateHandler)(void);
@property(nonatomic,copy) void (^minimizeHandler)(void);
@property(nonatomic,copy) void (^closeHandler)(void);
@property(nonatomic,copy) void (^geometryHandler)(CGRect frame);
@property(nonatomic,copy) void (^stateHandler)(void);
@property(nonatomic,copy) void (^snapPreviewHandler)(CGRect frame, BOOL visible);
@property(nonatomic,getter=isActive) BOOL active;
- (instancetype)initWithApplication:(MWApplication *)application frame:(CGRect)frame;
- (void)start;
- (void)applyViewport:(CGRect)viewport;
- (void)minimize;
- (void)restore;
- (void)close;
- (void)setHostVisible:(BOOL)visible;
- (void)toggleMaximize;
- (void)setInitialResizeMode:(MWResizeMode)mode;
- (void)cancelInteractions;
- (void)prepareKeyboardFocus;
@end

