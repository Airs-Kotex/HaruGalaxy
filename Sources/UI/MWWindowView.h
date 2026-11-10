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
@property(nonatomic,copy) void (^parkHandler)(void);
@property(nonatomic,copy) void (^restoreHandler)(void);
@property(nonatomic,copy) void (^geometryHandler)(CGRect frame);
@property(nonatomic,copy) void (^stateHandler)(void);
@property(nonatomic,copy) void (^snapPreviewHandler)(CGRect frame, BOOL visible);
@property(nonatomic,getter=isActive) BOOL active;
@property(nonatomic,readonly) BOOL compatibleCanvas;
@property(nonatomic,readonly,getter=isParked) BOOL parked;
@property(nonatomic,readonly) CGFloat parkedContentRatio;
@property(nonatomic,readonly) MWWindowModel restorableModel;
- (instancetype)initWithApplication:(MWApplication *)application frame:(CGRect)frame;
- (void)start;
- (void)applyViewport:(CGRect)viewport;
- (void)minimize;
- (void)restore;
- (void)close;
- (void)setHostVisible:(BOOL)visible;
- (void)toggleMaximize;
- (void)setInitialResizeMode:(MWResizeMode)mode;
- (void)setInitialCompatibleCanvas:(BOOL)enabled;
- (void)setInitialModel:(MWWindowModel)model;
- (void)setInitiallyParked:(BOOL)parked;
- (void)park;
- (void)placeParkedInFrame:(CGRect)frame;
- (void)cancelInteractions;
- (void)prepareKeyboardFocusForTouchInView:(UIView *)view;
- (void)recordTouchStartInView:(UIView *)view;
- (void)releaseForOriginalApplication:(void (^)(NSError *error))completion;
- (NSDictionary *)inputDiagnosticSnapshotWithCapabilities:(BOOL)capabilities;
@end

