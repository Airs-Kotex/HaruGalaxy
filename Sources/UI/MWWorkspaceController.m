// SPDX-License-Identifier: Apache-2.0
#import "MWWorkspaceController.h"
#import "MWWindowView.h"
#import "MWAppPickerController.h"
#import "MWSettingsController.h"
#import "MWDisplayOptionsController.h"
#import "MWPreferences.h"
#import "MWEdgeHandle.h"
#import "MWWindowPanel.h"
#import "MWWorkspaceCoordinator.h"
#import "../Diagnostics/MWDiagnostics.h"
#import "../Platform/MWFloatingHost.h"
#import "../Platform/MWKeyboardFocus.h"
#import "../Platform/MWApplicationActivation.h"
#import "../Platform/MWRuntimeDiagnostics.h"
#import "../Platform/MWDeviceOrientation.h"
#import "../Platform/MWBackgroundLease.h"
#import "../Core/MWGuestPolicy.h"
#import "../Core/MWOrientationState.h"

@interface MWCanvas : UIView
@property(nonatomic) BOOL passThrough;
@end
@implementation MWCanvas
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *hit=[super hitTest:point withEvent:event];
    // Hit-testing is queried by the native root bridge too; never change focus
    // or z-order here. Focus changes happen only after a real gesture ends.
    return self.passThrough && hit==self ? nil : hit;
}
@end

@interface MWWorkspaceController () <UIGestureRecognizerDelegate>
@end
@implementation MWWorkspaceController {
    MWCanvas *_canvas;
    NSMutableDictionary<NSString *,MWWindowView *> *_windows;
    NSMutableArray<NSString *> *_order;
    UILabel *_heading, *_subtitle, *_emptyTitle, *_emptyHint;
    UIButton *_add, *_settings;
    MWEdgeHandle *_bubble;
    MWWindowPanel *_panel;
    UIControl *_panelShield;
    UIView *_snapPreview;
    UILabel *_snapHint;
    CGRect _viewport;
    BOOL _hostHidden;
    MWWindowView *_nativeOpeningTarget;
    NSUInteger _nativeOpenGeneration;
    MWDeviceOrientation *_deviceOrientation;
    UIInterfaceOrientation _effectiveOrientation;
    UIEdgeInsets _workspaceSafeInsets;
    NSMutableDictionary<NSString *,MWWindowView *> *_closingWindows;
}
- (void)loadView {
    self.view=[MWCanvas new];
    _canvas=[MWCanvas new]; [self.view addSubview:_canvas];
}
- (void)viewDidLoad {
    [super viewDidLoad];
    _windows=[NSMutableDictionary dictionary]; _order=[NSMutableArray array];
    _closingWindows=[NSMutableDictionary dictionary];
    self.view.tintColor=[UIColor colorWithRed:0.05 green:0.52 blue:0.57 alpha:1];
    _heading=[self label:@"初春星河" size:32 weight:UIFontWeightBold color:UIColor.labelColor];
    _subtitle=[self label:@"HARUGALAXY / 多窗口工作台" size:12 weight:UIFontWeightSemibold color:UIColor.secondaryLabelColor];
    _emptyTitle=[self label:@"让应用，各得其所。" size:24 weight:UIFontWeightSemibold color:UIColor.labelColor];
    _emptyHint=[self label:@"左下 / 右上自由 · 左上 / 右下等比\n轻点边缘入口管理窗口" size:15 weight:UIFontWeightRegular color:UIColor.secondaryLabelColor];
    _emptyTitle.textAlignment=_emptyHint.textAlignment=NSTextAlignmentCenter; _emptyHint.numberOfLines=0;
    _add=[self button:@"plus" title:@"打开应用" action:@selector(openPicker)];
    if(@available(iOS 15.0,*)) {
        UIButtonConfiguration *addConfiguration=[UIButtonConfiguration filledButtonConfiguration];
        addConfiguration.title=@"打开应用"; addConfiguration.image=[UIImage systemImageNamed:@"plus"]; addConfiguration.imagePadding=8;
        _add.configuration=addConfiguration;
    } else {
        _add.backgroundColor=self.view.tintColor; _add.tintColor=UIColor.whiteColor; _add.layer.cornerRadius=12;
    }
    _settings=[self button:@"slider.horizontal.3" title:nil action:@selector(openSettings)]; _settings.accessibilityLabel=@"设置";
    _bubble=[MWEdgeHandle new]; [_canvas addSubview:_bubble];
    __weak typeof(self) weakSelf=self;
    _bubble.activationHandler=^{[weakSelf togglePanel];};
    _bubble.movementBeganHandler=^{[weakSelf closePanel];};
    _bubble.positionChangedHandler=^{[weakSelf.view setNeedsLayout];};
    _snapPreview=[UIView new]; _snapPreview.userInteractionEnabled=NO; _snapPreview.hidden=YES;
    _snapPreview.backgroundColor=[self.view.tintColor colorWithAlphaComponent:0.22];
    _snapPreview.layer.borderWidth=2; _snapPreview.layer.borderColor=self.view.tintColor.CGColor; _snapPreview.layer.cornerRadius=18;
    [_canvas addSubview:_snapPreview];
    _snapHint=[UILabel new]; _snapHint.text=@"松手进入半屏"; _snapHint.textAlignment=NSTextAlignmentCenter;
    _snapHint.textColor=UIColor.labelColor; _snapHint.font=[UIFont systemFontOfSize:18 weight:UIFontWeightSemibold]; [_snapPreview addSubview:_snapHint];
    _panelShield=[UIControl new]; _panelShield.backgroundColor=[UIColor.blackColor colorWithAlphaComponent:0.08];
    [_panelShield addTarget:self action:@selector(closePanel) forControlEvents:UIControlEventTouchUpInside];
    _panelShield.hidden=YES; [_canvas addSubview:_panelShield];
    _panel=[MWWindowPanel new]; _panel.hidden=YES; [_canvas addSubview:_panel];
    _panel.openApplicationHandler=^{[weakSelf closePanel]; [weakSelf openPicker];};
    _panel.settingsHandler=^{[weakSelf closePanel]; [weakSelf openSettings];};
    _panel.parkingSettingsHandler=^{[weakSelf closePanel]; [weakSelf openSettingsAtParking:YES];};
    _panel.displayOptionsHandler=^{[weakSelf openDisplayOptions];};
    _panel.openOriginalHandler=^(NSString *bundle){[weakSelf openOriginalBundle:bundle];};
    _panel.compatibleCanvasHandler=^(NSString *bundle,BOOL enabled){[weakSelf reopenBundle:bundle compatibleCanvas:enabled];};
    _panel.parkHandler=^(NSString *bundle){[weakSelf closePanel]; [weakSelf toggleParkBundle:bundle];};
    _panel.activateHandler=^(NSString *bundle){[weakSelf closePanel]; [weakSelf restoreBundle:bundle];};
    _panel.minimizeHandler=^(NSString *bundle){[weakSelf panelToggleMinimize:bundle];};
    _panel.fullscreenHandler=^(NSString *bundle){[weakSelf closePanel]; [weakSelf toggleFullscreenBundle:bundle];};
    _panel.closeHandler=^(NSString *bundle){[weakSelf closeBundle:bundle];};
    UITapGestureRecognizer *focus=[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(contentTapped:)];
    focus.delegate=self; focus.cancelsTouchesInView=NO; focus.delaysTouchesBegan=NO; focus.delaysTouchesEnded=NO;
    [self.view addGestureRecognizer:focus];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applyPreferences) name:MWPreferencesDidChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(floatingFailed:) name:MWFloatingHostFailedNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(captureKeyboardDiagnostics:) name:MWKeyboardDiagnosticSampleNotification object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(backgroundLeaseChanged:) name:MWBackgroundLeaseDidChangeNotification object:nil];
    _deviceOrientation=[MWDeviceOrientation new];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(physicalOrientationChanged:) name:MWDeviceOrientationDidChangeNotification object:_deviceOrientation];
    [_deviceOrientation start];
    [self applyPreferences]; [self updateChrome];
}
- (UILabel *)label:(NSString *)text size:(CGFloat)size weight:(UIFontWeight)weight color:(UIColor *)color {
    UILabel *label=[UILabel new]; label.text=text; label.font=[UIFont systemFontOfSize:size weight:weight]; label.textColor=color;
    [_canvas addSubview:label]; return label;
}
- (UIButton *)button:(NSString *)symbol title:(NSString *)title action:(SEL)action {
    UIButton *button=[UIButton buttonWithType:UIButtonTypeSystem];
    [button setImage:[UIImage systemImageNamed:symbol] forState:UIControlStateNormal];
    [button setTitle:title forState:UIControlStateNormal];
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    [_canvas addSubview:button]; return button;
}
- (void)setFloating:(BOOL)floating {
    if(_floating!=floating) [self cancelNativeOpen];
    _floating=floating;
    if(self.isViewLoaded) { [self closePanel]; [self updateChrome]; [self.view setNeedsLayout]; }
}
- (void)applyPreferences {
    // Both owning windows are synchronized by the coordinator. Keep this
    // movable controller inheriting its current window, including presented UI.
    [_bubble applyPreferences];
    for(MWWindowView *window in _windows.allValues) [window applyExecutionPolicy];
    [self updateChrome];
}
- (void)backgroundLeaseChanged:(NSNotification *)notification { (void)notification; [self refreshPanel]; }
- (void)physicalOrientationChanged:(NSNotification *)notification {
    (void)notification;
    for(MWWindowView *window in _windows.allValues) [window cancelInteractions];
    [_bubble cancelInteraction];
    [self.view setNeedsLayout];
}
- (BOOL)shouldAutorotate { return YES; }
- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIDevice.currentDevice.userInterfaceIdiom==UIUserInterfaceIdiomPad ? UIInterfaceOrientationMaskAll : UIInterfaceOrientationMaskAllButUpsideDown;
}
- (void)layoutOrientedCanvas {
    UIInterfaceOrientation host=self.view.window.windowScene.interfaceOrientation;
    if(host==UIInterfaceOrientationUnknown) host=UIInterfaceOrientationPortrait;
    UIInterfaceOrientation target=[_deviceOrientation orientationForHost:host floating:_floating];
    int turns=MWWorkspaceQuarterTurns((int)host,(int)target);
    CGSize size=self.view.bounds.size;
    if(abs(turns)%2) size=CGSizeMake(size.height,size.width);
    _canvas.bounds=(CGRect){CGPointZero,size};
    _canvas.center=CGPointMake(CGRectGetMidX(self.view.bounds),CGRectGetMidY(self.view.bounds));
    _canvas.transform=CGAffineTransformMakeRotation(turns*M_PI_2);
    CGRect safe=[_canvas convertRect:UIEdgeInsetsInsetRect(self.view.bounds,self.view.safeAreaInsets) fromView:self.view];
    _workspaceSafeInsets=UIEdgeInsetsMake(MAX(0,CGRectGetMinY(safe)),MAX(0,CGRectGetMinX(safe)),
        MAX(0,size.height-CGRectGetMaxY(safe)),MAX(0,size.width-CGRectGetMaxX(safe)));
    if(_effectiveOrientation!=target) {
        _effectiveOrientation=target;
        MWLog(@"orientation.workspace",@{@"interface":@(target),@"host":@(host),@"quarterTurns":@(turns),
            @"width":@(size.width),@"height":@(size.height)});
    }
}
- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    [self layoutOrientedCanvas];
    CGRect bounds=_canvas.bounds; UIEdgeInsets safe=_workspaceSafeInsets;
    CGFloat left=safe.left+20, width=bounds.size.width-safe.left-safe.right-40;
    _heading.frame=CGRectMake(left,safe.top+18,MAX(1,width-96),40);
    _subtitle.frame=CGRectMake(left,safe.top+61,width,20);
    _settings.frame=CGRectMake(bounds.size.width-safe.right-64,safe.top+22,44,44);
    CGFloat emptyY=MAX(safe.top+110,CGRectGetMidY(bounds)-80);
    _emptyTitle.frame=CGRectMake(left,emptyY,width,40);
    _emptyHint.frame=CGRectMake(left,emptyY+48,width,62);
    _add.frame=CGRectMake(CGRectGetMidX(bounds)-90,emptyY+128,180,48);
    [_bubble applyViewport:CGRectMake(0,safe.top+12,bounds.size.width,MAX(1,bounds.size.height-safe.top-safe.bottom-24))];
    if(!_panel.hidden) {
        _panelShield.frame=bounds;
        [_panel placeNearAnchor:_bubble.frame inBounds:UIEdgeInsetsInsetRect(bounds,safe)];
    }
    _snapHint.frame=CGRectMake(8,CGRectGetMidY(_snapPreview.bounds)-22,MAX(1,_snapPreview.bounds.size.width-16),44);
    CGRect viewport=bounds;
    _viewport=viewport;
    for(MWWindowView *window in _windows.allValues)
        [window applyViewport:viewport orientation:_effectiveOrientation safeInsets:safe];
    NSMutableArray<MWWindowView *> *parked=[NSMutableArray array];
    for(NSString *bundle in _order.reverseObjectEnumerator)
        if(_windows[bundle].isParked) [parked addObject:_windows[bundle]];
    CGRect safeBounds=UIEdgeInsetsInsetRect(bounds,safe);
    for(NSUInteger i=0;i<parked.count;i++) {
        MWWindowView *window=parked[i];
        MWRect r=MWParkedRect((MWRect){safeBounds.origin.x,safeBounds.origin.y,safeBounds.size.width,safeBounds.size.height},
            window.parkedContentRatio,MWPreferences.shared.parkedSizeFraction,MWPreferences.shared.parkedAspectRatio,(unsigned)i,(unsigned)parked.count);
        [window placeParkedInFrame:CGRectMake(r.x,r.y,r.width,r.height)];
    }
}
- (void)updateChrome {
    if(!self.isViewLoaded) return;
    [_deviceOrientation setTrackingEnabled:!_hostHidden && _windows.count>0];
    self.view.backgroundColor=_floating ? UIColor.clearColor : UIColor.systemGroupedBackgroundColor;
    self.view.opaque=!_floating; self.view.layer.opaque=!_floating;
    _canvas.passThrough=_floating;
    ((MWCanvas *)self.view).passThrough=_floating;
    _heading.hidden=_subtitle.hidden=_settings.hidden=_floating;
    _emptyTitle.hidden=_emptyHint.hidden=_add.hidden=_floating || _windows.count>0;
    _bubble.hidden=!_floating && _windows.count==0;
    [self refreshPanel];
    [self raiseControls];
    [self setNeedsStatusBarAppearanceUpdate]; [self setNeedsUpdateOfHomeIndicatorAutoHidden];
    [self setNeedsUpdateOfScreenEdgesDeferringSystemGestures];
    [self.view setNeedsLayout];
}
- (void)refreshPanel {
    NSUInteger minimized=0; NSMutableArray *windows=[NSMutableArray array];
    for(NSString *bundle in _order.reverseObjectEnumerator) {
        MWWindowView *window=_windows[bundle];
        if(window) [windows addObject:window];
        if(window.model.state==MWWindowMinimized) minimized++;
    }
    _bubble.minimizedCount=minimized;
    if(!_panel.hidden) [_panel updateWindows:windows];
}
- (void)raiseControls {
    for(NSString *bundle in _order) if(_windows[bundle].isParked) [_canvas bringSubviewToFront:_windows[bundle]];
    if(!_snapPreview.hidden) [_canvas bringSubviewToFront:_snapPreview];
    if(!_panel.hidden) { [_canvas bringSubviewToFront:_panelShield]; [_canvas bringSubviewToFront:_panel]; }
    [_canvas bringSubviewToFront:_bubble];
}
- (void)togglePanel {
    if(_nativeOpeningTarget) { [self closePanel]; return; }
    if(self.presentedViewController) {
        MWLog(@"panel.blocked",@{@"reason":@"presented_controller",@"controller":NSStringFromClass(self.presentedViewController.class)});
        return;
    }
    if(!_panel.hidden) { [self closePanel]; return; }
    CFTimeInterval started=CACurrentMediaTime();
    [MWKeyboardFocus.shared focusHostWindow:self.view.window reason:@"window_panel"];
    for(MWWindowView *window in _windows.allValues) [window cancelInteractions];
    _panel.hidden=NO; _panelShield.hidden=NO; _bubble.panelOpen=YES;
    [self refreshPanel]; [self raiseControls]; [self.view setNeedsLayout]; [self.view layoutIfNeeded];
    MWLog(@"panel.open",@{@"windows":@(_windows.count),@"minimized":@(_bubble.minimizedCount),
        @"preparationMs":@((CACurrentMediaTime()-started)*1000),@"rowsCreated":@(_panel.createdRowCount)});
}
- (void)closePanel {
    if(!_panel || _panel.hidden) return;
    _panel.hidden=YES; _panelShield.hidden=YES; _bubble.panelOpen=NO;
    MWLog(@"panel.close",@{});
}
- (void)panelToggleMinimize:(NSString *)bundle {
    if(_windows[bundle].model.state==MWWindowMinimized) { [self closePanel]; [self restoreBundle:bundle]; }
    else [self minimizeBundle:bundle];
}
- (void)toggleFullscreenBundle:(NSString *)bundle {
    if(_nativeOpeningTarget) return;
    [self restoreBundle:bundle];
    MWWindowView *window=_windows[bundle]; [window toggleMaximize]; [self updateChrome];
}
- (void)toggleParkBundle:(NSString *)bundle {
    if(_nativeOpeningTarget || _hostHidden || MWFloatingHost.shared.isLocked) return;
    MWWindowView *window=_windows[bundle];
    if(window.isParked) { [self restoreBundle:bundle]; return; }
    if(!window || window.model.state!=MWWindowVisible) return;
    // A loading surface can finish after native-app switching collected it.
    // Reattach that exact view before asking it to become a visible thumbnail.
    if(window.superview!=_canvas) [_canvas addSubview:window];
    [window setHostVisible:YES];
    [window park];
    for(NSString *candidate in [[_order copy] reverseObjectEnumerator]) {
        MWWindowView *other=_windows[candidate];
        if(other && other.model.state==MWWindowVisible && !other.hidden && other.superview==_canvas) {
            [self activateBundle:candidate]; break;
        }
    }
    [self updateChrome];
}
- (BOOL)hasVisibleFullscreen {
    for(MWWindowView *window in _windows.allValues) if(window.model.maximized && !window.hidden && window.model.state==MWWindowVisible) return YES;
    return NO;
}
- (BOOL)prefersStatusBarHidden { return [self hasVisibleFullscreen]; }
- (BOOL)prefersHomeIndicatorAutoHidden { return [self hasVisibleFullscreen]; }
- (UIRectEdge)preferredScreenEdgesDeferringSystemGestures { return [self hasVisibleFullscreen] ? UIRectEdgeAll : UIRectEdgeNone; }
- (void)openPicker {
    [self closePanel];
    if(self.presentedViewController || _nativeOpeningTarget) return;
    [MWKeyboardFocus.shared focusHostWindow:self.view.window reason:@"open_picker"];
    MWAppPickerController *picker=[MWAppPickerController new];
    __weak typeof(self) weakSelf=self;
    picker.selectionHandler=^(MWApplication *app) { [weakSelf openApplication:app]; };
    if(_floating) picker.searchFallbackHandler=^(NSString *query) {
        [MWWorkspaceCoordinator.shared presentApplicationSearchWithQuery:query selection:^(MWApplication *app){[weakSelf openApplication:app];}];
    };
    UINavigationController *nav=[[UINavigationController alloc] initWithRootViewController:picker];
    nav.modalPresentationStyle=UIModalPresentationPageSheet;
    [self presentViewController:nav animated:!MWPreferences.shared.reduceMotion completion:nil];
}
- (void)openOriginalBundle:(NSString *)bundle {
    if(_closingWindows[bundle]) return;
    MWWindowView *target=_windows[bundle];
    if(!target || self.presentedViewController || _nativeOpeningTarget || _hostHidden || MWFloatingHost.shared.isLocked) return;
    NSError *preflight=[target.session originalApplicationHandoffIssue];
    if(preflight) { [self closePanel]; [self showMessage:preflight.localizedDescription]; return; }
    [self closePanel]; [self.view endEditing:YES];
    NSArray<NSString *> *order=[_order copy];
    NSMutableArray<MWWindowView *> *attached=[NSMutableArray array], *visible=[NSMutableArray array];
    for(NSString *identifier in order) {
        MWWindowView *window=_windows[identifier];
        if(!window || window==target) continue;
        window.active=NO;
        if(window.superview==_canvas) [attached addObject:window];
        if(window.model.state==MWWindowVisible) { [visible addObject:window]; [window minimize]; }
        // Also collect loading/failed surfaces: their asynchronous completion
        // must not place a window over the ordinary application's keyboard.
        [window setHostVisible:NO]; [window removeFromSuperview];
    }
    MWRect r=target.model.maximized ? target.model.restoreFrame : target.model.frame;
    [MWPreferences.shared saveFrame:CGRectMake(r.x,r.y,r.width,r.height) forBundle:bundle viewport:_viewport];
    [MWPreferences.shared saveResizeMode:target.model.maximized ? target.model.restoreResizeMode : target.model.resizeMode forBundle:bundle];
    _nativeOpeningTarget=target;
    NSUInteger generation=++_nativeOpenGeneration;
    [_windows removeObjectForKey:bundle]; [_order removeObject:bundle];
    __weak typeof(self) weakSelf=self;
    __weak MWWindowView *weakTarget=target;
    [target releaseForOriginalApplication:^(NSError *releaseError) {
        MWWorkspaceController *controller=weakSelf; MWWindowView *owned=weakTarget;
        if(!controller || generation!=controller->_nativeOpenGeneration ||
           !owned || controller->_nativeOpeningTarget!=owned) return;
        [controller closePanel];
        controller->_nativeOpeningTarget=nil;
        if(controller->_hostHidden || MWFloatingHost.shared.isLocked) return;
        [MWKeyboardFocus.shared releaseForWindow:controller.view.window];
        [controller.view.window resignKeyWindow];
        NSError *error=releaseError;
        if(!error && [MWKeyboardFocus.shared hasPendingCleanup])
            error=[NSError errorWithDomain:@"HaruGalaxy" code:66 userInfo:@{NSLocalizedDescriptionKey:@"输入清理未完成，未打开原应用。请导出诊断并重启初春星河。"}];
        BOOL accepted=!error && MWRequestApplicationForeground(bundle,&error);
        MWLog(@"native_handoff.open_requested",@{@"bundle":bundle,@"accepted":@(accepted),@"error":MWErrorFields(error)});
        if(!accepted) {
            // A preflight can fail after another guest's input cleanup. If
            // release never began, keep this exact target instead of losing it.
            MWWindowView *retained=owned;
            if(retained && retained.model.state!=MWWindowClosed) {
                controller->_windows[bundle]=retained;
                [controller->_order addObject:bundle];
            }
            // The target session has ended. Never silently recreate it while
            // the ordinary App may be connecting; only restore other surfaces.
            for(MWWindowView *window in attached) {
                if(controller->_windows[window.application.bundleIdentifier]!=window) continue;
                [controller->_canvas addSubview:window]; [window setHostVisible:YES];
                if([visible containsObject:window]) [window restore];
            }
            [controller.view.window makeKeyWindow];
            [controller showMessage:error.localizedDescription ?: @"未能打开原应用。该小窗已结束，可从主屏幕打开应用。"];
        }
        [controller updateChrome];
    }];
    [self updateChrome];
}
- (void)cancelNativeOpen {
    MWWindowView *target=_nativeOpeningTarget; _nativeOpeningTarget=nil; _nativeOpenGeneration++;
    if(target) MWLog(@"native_handoff.cancelled",@{@"bundle":target.application.bundleIdentifier});
    [target close];
}
- (void)reopenBundle:(NSString *)bundle compatibleCanvas:(BOOL)enabled {
    if(_closingWindows[bundle]) return;
    MWWindowView *target=_windows[bundle];
    if(!target || _nativeOpeningTarget || self.presentedViewController || _hostHidden || MWFloatingHost.shared.isLocked) return;
    NSError *preflight=[target.session originalApplicationHandoffIssue];
    [self closePanel];
    if(preflight) { [self showMessage:preflight.localizedDescription]; return; }
    MWWindowModel savedModel=target.restorableModel;
    BOOL wasParked=target.isParked;
    MWRect r=savedModel.maximized ? savedModel.restoreFrame : savedModel.frame;
    [MWPreferences.shared saveFrame:CGRectMake(r.x,r.y,r.width,r.height) forBundle:bundle viewport:_viewport];
    [MWPreferences.shared saveResizeMode:target.model.maximized ? target.model.restoreResizeMode : target.model.resizeMode forBundle:bundle];
    _nativeOpeningTarget=target;
    NSUInteger generation=++_nativeOpenGeneration;
    [_windows removeObjectForKey:bundle]; [_order removeObject:bundle];
    __weak typeof(self) weakSelf=self; __weak MWWindowView *weakTarget=target;
    [target releaseForOriginalApplication:^(NSError *error) {
        MWWorkspaceController *controller=weakSelf; MWWindowView *owned=weakTarget;
        if(!controller || !owned || generation!=controller->_nativeOpenGeneration || controller->_nativeOpeningTarget!=owned) return;
        [controller closePanel]; controller->_nativeOpeningTarget=nil;
        if(controller->_hostHidden || MWFloatingHost.shared.isLocked) return;
        MWLog(@"workspace.compatibility_reopen",@{@"bundle":bundle,@"compatible":@(enabled),@"error":MWErrorFields(error)});
        if(error) {
            if(owned.model.state!=MWWindowClosed) {
                controller->_windows[bundle]=owned; [controller->_order addObject:bundle];
            }
            [controller updateChrome]; [controller showMessage:error.localizedDescription]; return;
        }
        [MWPreferences.shared saveCompatibleCanvas:enabled forBundle:bundle];
        [controller openApplication:owned.application restoringModel:&savedModel initiallyParked:wasParked];
    }];
    [self updateChrome];
}
- (void)openDisplayOptions {
    [self closePanel];
    if(_nativeOpeningTarget || self.presentedViewController || _hostHidden || MWFloatingHost.shared.isLocked) return;
    NSMutableArray *rows=[NSMutableArray array]; NSMutableDictionary *targets=[NSMutableDictionary dictionary];
    for(NSString *bundle in _order.reverseObjectEnumerator) {
        MWWindowView *window=_windows[bundle]; if(!window) continue;
        [rows addObject:@{@"bundle":bundle,@"name":window.application.name ?: bundle,@"compatible":@(window.compatibleCanvas)}];
        targets[bundle]=window;
    }
    [MWKeyboardFocus.shared focusHostWindow:self.view.window reason:@"display_options"];
    MWDisplayOptionsController *options=[MWDisplayOptionsController new]; options.windows=rows;
    __weak typeof(self) weakSelf=self;
    options.selectionHandler=^(NSString *bundle,BOOL compatible) {
        MWWorkspaceController *controller=weakSelf;
        if(controller && controller->_windows[bundle]==targets[bundle]) [controller reopenBundle:bundle compatibleCanvas:compatible];
    };
    MWLog(@"workspace.display_options",@{@"windows":@(rows.count)});
    [self presentViewController:[[UINavigationController alloc] initWithRootViewController:options] animated:!MWPreferences.shared.reduceMotion completion:nil];
}
- (void)openApplication:(MWApplication *)application {
    [self openApplication:application restoringModel:NULL initiallyParked:NO];
}
- (void)openApplication:(MWApplication *)application restoringModel:(const MWWindowModel *)savedModel initiallyParked:(BOOL)parked {
    if(_nativeOpeningTarget) return;
    if(_closingWindows[application.bundleIdentifier]) { [self showMessage:@"该应用正在结束，请稍后重新打开。"]; return; }
    MWLog(@"workspace.open",@{@"bundle":application.bundleIdentifier,@"floating":@(_floating)});
    MWWindowView *existing=_windows[application.bundleIdentifier];
    if(existing) { [self restoreBundle:application.bundleIdentifier]; return; }
    if(_windows.count>=4) { [self showMessage:@"最多同时保留 4 个窗口，请先关闭一个。"] ; return; }
    [self.view layoutIfNeeded];
    CGFloat offset=(_windows.count%3)*20;
    CGRect frame=CGRectMake(_viewport.origin.x+12+offset,_workspaceSafeInsets.top+24+offset,MIN(340,_viewport.size.width),MIN(460,_viewport.size.height));
    frame=[MWPreferences.shared frameForBundle:application.bundleIdentifier viewport:_viewport fallback:frame];
    CGRect initialViewport=_viewport;
    initialViewport.origin.y+=_workspaceSafeInsets.top;
    initialViewport.size.height=MAX(1,initialViewport.size.height-_workspaceSafeInsets.top);
    MWRect placed=MWConstrainExistingRect((MWRect){frame.origin.x,frame.origin.y,frame.size.width,frame.size.height},
        (MWRect){initialViewport.origin.x,initialViewport.origin.y,initialViewport.size.width,initialViewport.size.height});
    frame=savedModel ? CGRectMake(savedModel->frame.x,savedModel->frame.y,savedModel->frame.width,savedModel->frame.height) :
        CGRectMake(placed.x,placed.y,placed.width,placed.height);
    MWWindowView *window=[[MWWindowView alloc] initWithApplication:application frame:frame];
    [window setInitialCompatibleCanvas:[MWPreferences.shared compatibleCanvasForBundle:application.bundleIdentifier]];
    [window setInitiallyParked:parked];
    [window setInitialResizeMode:[MWPreferences.shared resizeModeForBundle:application.bundleIdentifier]];
    if(savedModel) {
        MWWindowModel restored=MWWindowRestoreForLaunch(*savedModel,(MWRect){_viewport.origin.x,_viewport.origin.y,_viewport.size.width,_viewport.size.height});
        [window setInitialModel:restored];
    }
    NSString *bundle=application.bundleIdentifier;
    _windows[bundle]=window; [_order addObject:bundle];
    __weak typeof(self) weakSelf=self;
    window.activateHandler=^{[weakSelf activateBundle:bundle];};
    window.closeHandler=^{[weakSelf closeBundle:bundle];};
    window.minimizeHandler=^{[weakSelf minimizeBundle:bundle];};
    window.parkHandler=^{[weakSelf toggleParkBundle:bundle];};
    window.restoreHandler=^{[weakSelf restoreBundle:bundle];};
    window.geometryHandler=^(CGRect geometry) {
        MWWorkspaceController *controller=weakSelf;
        if(controller) {
            [MWPreferences.shared saveFrame:geometry forBundle:bundle viewport:controller->_viewport];
            [MWPreferences.shared saveResizeMode:controller->_windows[bundle].model.resizeMode forBundle:bundle];
        }
    };
    window.stateHandler=^{ [weakSelf updateChrome]; };
    window.snapPreviewHandler=^(CGRect preview,BOOL visible) {
        MWWorkspaceController *controller=weakSelf;
        if(!controller) return;
        controller->_snapPreview.hidden=!visible; controller->_snapPreview.frame=preview;
        [controller raiseControls]; [controller.view setNeedsLayout];
    };
    [_canvas addSubview:window]; [window applyViewport:_viewport orientation:_effectiveOrientation safeInsets:_workspaceSafeInsets];
    [self activateBundle:bundle]; [MWPreferences.shared recordUse:bundle];
    [self updateChrome]; [window start];
    [window setHostVisible:!_hostHidden];
}
- (void)activateBundle:(NSString *)bundle {
    if(_nativeOpeningTarget) return;
    MWWindowView *selected=_windows[bundle];
    if(!selected || selected.model.state==MWWindowClosed || selected.isParked || selected.superview!=_canvas) return;
    for(MWWindowView *window in _windows.allValues) window.active=(window==selected);
    [_canvas bringSubviewToFront:selected];
    [_order removeObject:bundle]; [_order addObject:bundle];
    [self raiseControls];
    if(!_hostHidden && _panel.hidden && !self.presentedViewController && !selected.hidden &&
       selected.model.state==MWWindowVisible)
        [selected.session requestKeyboardFocusInWindow:self.view.window];
    [self setNeedsStatusBarAppearanceUpdate]; [self setNeedsUpdateOfHomeIndicatorAutoHidden];
}
- (void)restoreBundle:(NSString *)bundle {
    if(_nativeOpeningTarget) return;
    MWWindowView *window=_windows[bundle];
    if(!window) return;
    if(window.userClosePending) return;
    if(window.superview!=_canvas) [_canvas addSubview:window];
    [window setHostVisible:!_hostHidden]; [window restore];
    [self activateBundle:bundle]; [self updateChrome];
}
- (void)minimizeBundle:(NSString *)bundle {
    [_windows[bundle] minimize];
    for(NSString *candidate in [[_order copy] reverseObjectEnumerator])
        if(_windows[candidate].model.state==MWWindowVisible) { [self activateBundle:candidate]; break; }
    [self updateChrome];
}
- (void)closeBundle:(NSString *)bundle {
    MWWindowView *window=_windows[bundle];
    if(!window || window.userClosePending) return;
    MWRect r=window.model.maximized ? window.model.restoreFrame : window.model.frame;
    [MWPreferences.shared saveFrame:CGRectMake(r.x,r.y,r.width,r.height) forBundle:bundle viewport:_viewport];
    [MWPreferences.shared saveResizeMode:window.model.maximized ? window.model.restoreResizeMode : window.model.resizeMode forBundle:bundle];
    _closingWindows[bundle]=window;
    __weak typeof(self) weakSelf=self;
    [window closeAfterUserRequest:^(NSError *error) {
        MWWorkspaceController *controller=weakSelf;
        if(!controller) return;
        if(!error) {
            [controller->_closingWindows removeObjectForKey:bundle];
            [controller->_windows removeObjectForKey:bundle]; [controller->_order removeObject:bundle];
        }
        [controller updateChrome];
    }];
    for(NSString *candidate in [[_order copy] reverseObjectEnumerator])
        if(!_windows[candidate].hidden && _windows[candidate].model.state==MWWindowVisible) { [self activateBundle:candidate]; break; }
    [self updateChrome];
}
- (void)closeAllWindows {
    [self cancelNativeOpen];
    // Host teardown is not an explicit user request to terminate guest apps.
    for(NSString *bundle in [_order copy]) {
        if(_closingWindows[bundle]) continue;
        [_windows[bundle] close]; [_windows removeObjectForKey:bundle]; [_order removeObject:bundle];
    }
    [self updateChrome];
}
- (void)setHostVisible:(BOOL)visible {
    MWLog(@"workspace.visibility",@{@"visible":@(visible),@"floating":@(_floating),@"windows":@(_windows.count)});
    _hostHidden=!visible;
    [_deviceOrientation setTrackingEnabled:visible && _windows.count>0];
    if(!visible) { [self cancelNativeOpen]; [_bubble cancelInteraction]; [self closePanel]; }
    for(MWWindowView *window in _windows.allValues) [window setHostVisible:visible && window.superview==_canvas];
}
- (void)openSettings {
    [self openSettingsAtParking:NO];
}
- (void)openSettingsAtParking:(BOOL)parking {
    [self closePanel];
    if(self.presentedViewController || _nativeOpeningTarget) return;
    [MWKeyboardFocus.shared focusHostWindow:self.view.window reason:@"settings"];
    MWSettingsController *settings=[MWSettingsController new];
    settings.showParkingSettings=parking;
    __weak typeof(self) weakSelf=self;
    settings.floatingHandler=^(BOOL enabled) {
        NSError *error=nil;
        if(![MWFloatingHost.shared setEnabled:enabled fromScene:weakSelf.view.window.windowScene error:&error]) [weakSelf showMessage:error.localizedDescription];
    };
    [self presentViewController:[[UINavigationController alloc] initWithRootViewController:settings] animated:YES completion:nil];
}
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gesture shouldReceiveTouch:(UITouch *)touch {
    (void)gesture;
    if(!_panel.hidden) return NO;
    for(UIView *view=touch.view;view && view!=self.view;view=view.superview)
        if([view isKindOfClass:UIControl.class]) return NO;
    return YES;
}
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)first shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)second { (void)first; (void)second; return YES; }
- (void)contentTapped:(UITapGestureRecognizer *)gesture {
    if(gesture.state!=UIGestureRecognizerStateRecognized || !_panel.hidden) return;
    UIView *hit=[self.view hitTest:[gesture locationInView:self.view] withEvent:nil];
    for(UIView *view=hit;view && view!=self.view;view=view.superview)
        if([view isKindOfClass:MWWindowView.class]) { [self activateBundle:((MWWindowView *)view).application.bundleIdentifier]; break; }
}
- (void)floatingFailed:(NSNotification *)notification { [self showMessage:[notification.object localizedDescription]]; }
- (void)captureKeyboardDiagnostics:(NSNotification *)notification {
    BOOL capabilities=[notification.userInfo[@"capabilities"] boolValue];
    NSMutableArray *guests=[NSMutableArray array],*windows=[NSMutableArray array];
    for(NSString *bundle in _order) {
        MWWindowView *view=_windows[bundle];
        if(view) [guests addObject:[view inputDiagnosticSnapshotWithCapabilities:capabilities]];
    }
    for(UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if(![scene isKindOfClass:UIWindowScene.class]) continue;
        for(UIWindow *window in ((UIWindowScene *)scene).windows) {
            if(windows.count>=32) break;
            [windows addObject:MWDiagnosticWindow(window)];
        }
    }
    MWLog(@"keyboard.diagnostic_sample",@{@"context":notification.userInfo ?: @{},@"floating":@(_floating),@"hostHidden":@(_hostHidden),
        @"orientationSource":[_deviceOrientation diagnosticSnapshot],
        @"appearance":@{@"preference":@(MWPreferences.shared.appearance),@"workspace":@(self.traitCollection.userInterfaceStyle),
            @"window":@(self.view.window.traitCollection.userInterfaceStyle),@"scene":@(self.view.window.windowScene.traitCollection.userInterfaceStyle)},
        @"panelVisible":@(!_panel.hidden),@"modalVisible":@(self.presentedViewController!=nil),
        @"focus":[MWKeyboardFocus.shared diagnosticSnapshotWithCapabilities:capabilities],@"guests":guests,@"windows":windows});
}
- (void)showMessage:(NSString *)message {
    if(!message.length || self.presentedViewController) return;
    UIAlertController *alert=[UIAlertController alertControllerWithTitle:@"初春星河" message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"知道了" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}
- (void)dealloc { [_deviceOrientation stop]; [[NSNotificationCenter defaultCenter] removeObserver:self]; }
@end
