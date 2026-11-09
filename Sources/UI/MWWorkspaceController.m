// SPDX-License-Identifier: Apache-2.0
#import "MWWorkspaceController.h"
#import "MWWindowView.h"
#import "MWAppPickerController.h"
#import "MWSettingsController.h"
#import "MWPreferences.h"
#import "MWEdgeHandle.h"
#import "MWWindowPanel.h"
#import "MWWorkspaceCoordinator.h"
#import "../Diagnostics/MWDiagnostics.h"
#import "../Platform/MWFloatingHost.h"
#import "../Platform/MWKeyboardFocus.h"

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
}
- (void)loadView {
    _canvas=[MWCanvas new]; self.view=_canvas;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    _windows=[NSMutableDictionary dictionary]; _order=[NSMutableArray array];
    self.view.tintColor=[UIColor colorWithRed:0.05 green:0.52 blue:0.57 alpha:1];
    _heading=[self label:@"初春星河" size:32 weight:UIFontWeightBold color:UIColor.labelColor];
    _subtitle=[self label:@"HARUGALAXY / 多窗口工作台" size:12 weight:UIFontWeightSemibold color:UIColor.secondaryLabelColor];
    _emptyTitle=[self label:@"让应用，各得其所。" size:24 weight:UIFontWeightSemibold color:UIColor.labelColor];
    _emptyHint=[self label:@"右上自由缩放 · 右下原始比例\n轻点边缘入口管理窗口" size:15 weight:UIFontWeightRegular color:UIColor.secondaryLabelColor];
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
    _bubble=[MWEdgeHandle new]; [self.view addSubview:_bubble];
    __weak typeof(self) weakSelf=self;
    _bubble.activationHandler=^{[weakSelf togglePanel];};
    _bubble.movementBeganHandler=^{[weakSelf closePanel];};
    _bubble.positionChangedHandler=^{[weakSelf.view setNeedsLayout];};
    _snapPreview=[UIView new]; _snapPreview.userInteractionEnabled=NO; _snapPreview.hidden=YES;
    _snapPreview.backgroundColor=[self.view.tintColor colorWithAlphaComponent:0.22];
    _snapPreview.layer.borderWidth=2; _snapPreview.layer.borderColor=self.view.tintColor.CGColor; _snapPreview.layer.cornerRadius=18;
    [self.view addSubview:_snapPreview];
    _snapHint=[UILabel new]; _snapHint.text=@"松手进入半屏"; _snapHint.textAlignment=NSTextAlignmentCenter;
    _snapHint.textColor=UIColor.labelColor; _snapHint.font=[UIFont systemFontOfSize:18 weight:UIFontWeightSemibold]; [_snapPreview addSubview:_snapHint];
    _panelShield=[UIControl new]; _panelShield.backgroundColor=[UIColor.blackColor colorWithAlphaComponent:0.08];
    [_panelShield addTarget:self action:@selector(closePanel) forControlEvents:UIControlEventTouchUpInside];
    _panelShield.hidden=YES; [self.view addSubview:_panelShield];
    _panel=[MWWindowPanel new]; _panel.hidden=YES; [self.view addSubview:_panel];
    _panel.openApplicationHandler=^{[weakSelf closePanel]; [weakSelf openPicker];};
    _panel.settingsHandler=^{[weakSelf closePanel]; [weakSelf openSettings];};
    _panel.activateHandler=^(NSString *bundle){[weakSelf closePanel]; [weakSelf restoreBundle:bundle];};
    _panel.minimizeHandler=^(NSString *bundle){[weakSelf panelToggleMinimize:bundle];};
    _panel.fullscreenHandler=^(NSString *bundle){[weakSelf closePanel]; [weakSelf toggleFullscreenBundle:bundle];};
    _panel.closeHandler=^(NSString *bundle){[weakSelf closeBundle:bundle];};
    UITapGestureRecognizer *focus=[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(contentTapped:)];
    focus.delegate=self; focus.cancelsTouchesInView=NO; focus.delaysTouchesBegan=NO; focus.delaysTouchesEnded=NO;
    [self.view addGestureRecognizer:focus];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applyPreferences) name:MWPreferencesDidChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(floatingFailed:) name:MWFloatingHostFailedNotification object:nil];
    [self applyPreferences]; [self updateChrome];
}
- (UILabel *)label:(NSString *)text size:(CGFloat)size weight:(UIFontWeight)weight color:(UIColor *)color {
    UILabel *label=[UILabel new]; label.text=text; label.font=[UIFont systemFontOfSize:size weight:weight]; label.textColor=color;
    [self.view addSubview:label]; return label;
}
- (UIButton *)button:(NSString *)symbol title:(NSString *)title action:(SEL)action {
    UIButton *button=[UIButton buttonWithType:UIButtonTypeSystem];
    [button setImage:[UIImage systemImageNamed:symbol] forState:UIControlStateNormal];
    [button setTitle:title forState:UIControlStateNormal];
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:button]; return button;
}
- (void)setFloating:(BOOL)floating {
    _floating=floating;
    if(self.isViewLoaded) { [self closePanel]; [self updateChrome]; [self.view setNeedsLayout]; }
}
- (void)applyPreferences {
    self.overrideUserInterfaceStyle=MWPreferences.shared.appearance;
    self.view.window.overrideUserInterfaceStyle=MWPreferences.shared.appearance;
    [_bubble applyPreferences];
    [self updateChrome];
}
- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGRect bounds=self.view.bounds; UIEdgeInsets safe=self.view.safeAreaInsets;
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
    if(!CGRectEqualToRect(_viewport,viewport)) {
        _viewport=viewport;
        for(MWWindowView *window in _windows.allValues) [window applyViewport:viewport];
    }
}
- (void)updateChrome {
    if(!self.isViewLoaded) return;
    self.view.backgroundColor=_floating ? UIColor.clearColor : UIColor.systemGroupedBackgroundColor;
    self.view.opaque=!_floating; self.view.layer.opaque=!_floating;
    _canvas.passThrough=_floating;
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
    if(!_snapPreview.hidden) [self.view bringSubviewToFront:_snapPreview];
    if(!_panel.hidden) { [self.view bringSubviewToFront:_panelShield]; [self.view bringSubviewToFront:_panel]; }
    [self.view bringSubviewToFront:_bubble];
}
- (void)togglePanel {
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
    MWWindowView *window=_windows[bundle]; [window restore]; [window toggleMaximize]; [self updateChrome];
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
    if(self.presentedViewController) return;
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
- (void)openApplication:(MWApplication *)application {
    MWLog(@"workspace.open",@{@"bundle":application.bundleIdentifier,@"floating":@(_floating)});
    MWWindowView *existing=_windows[application.bundleIdentifier];
    if(existing) { [self restoreBundle:application.bundleIdentifier]; return; }
    if(_windows.count>=4) { [self showMessage:@"最多同时保留 4 个窗口，请先关闭一个。"] ; return; }
    [self.view layoutIfNeeded];
    CGFloat offset=(_windows.count%3)*20;
    CGRect frame=CGRectMake(_viewport.origin.x+12+offset,self.view.safeAreaInsets.top+24+offset,MIN(340,_viewport.size.width),MIN(460,_viewport.size.height));
    frame=[MWPreferences.shared frameForBundle:application.bundleIdentifier viewport:_viewport fallback:frame];
    CGRect initialViewport=_viewport;
    initialViewport.origin.y+=self.view.safeAreaInsets.top;
    initialViewport.size.height=MAX(1,initialViewport.size.height-self.view.safeAreaInsets.top);
    MWRect placed=MWConstrainRect((MWRect){frame.origin.x,frame.origin.y,frame.size.width,frame.size.height},
        (MWRect){initialViewport.origin.x,initialViewport.origin.y,initialViewport.size.width,initialViewport.size.height});
    frame=CGRectMake(placed.x,placed.y,placed.width,placed.height);
    MWWindowView *window=[[MWWindowView alloc] initWithApplication:application frame:frame];
    [window setInitialResizeMode:[MWPreferences.shared resizeModeForBundle:application.bundleIdentifier]];
    NSString *bundle=application.bundleIdentifier;
    _windows[bundle]=window; [_order addObject:bundle];
    __weak typeof(self) weakSelf=self;
    window.activateHandler=^{[weakSelf activateBundle:bundle];};
    window.closeHandler=^{[weakSelf closeBundle:bundle];};
    window.minimizeHandler=^{[weakSelf minimizeBundle:bundle];};
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
    [self.view addSubview:window]; [window applyViewport:_viewport];
    [self activateBundle:bundle]; [MWPreferences.shared recordUse:bundle];
    [self updateChrome]; [window start];
    [window setHostVisible:!_hostHidden];
}
- (void)activateBundle:(NSString *)bundle {
    MWWindowView *selected=_windows[bundle];
    if(!selected || selected.model.state==MWWindowClosed) return;
    for(MWWindowView *window in _windows.allValues) window.active=(window==selected);
    [self.view bringSubviewToFront:selected];
    [_order removeObject:bundle]; [_order addObject:bundle];
    [self raiseControls];
    if(!_hostHidden && _panel.hidden && !self.presentedViewController && !selected.hidden &&
       selected.model.state==MWWindowVisible)
        [selected.session requestKeyboardFocusInWindow:self.view.window];
    [self setNeedsStatusBarAppearanceUpdate]; [self setNeedsUpdateOfHomeIndicatorAutoHidden];
}
- (void)restoreBundle:(NSString *)bundle { [_windows[bundle] restore]; [self activateBundle:bundle]; [self updateChrome]; }
- (void)minimizeBundle:(NSString *)bundle {
    [_windows[bundle] minimize];
    for(NSString *candidate in [[_order copy] reverseObjectEnumerator])
        if(_windows[candidate].model.state==MWWindowVisible) { [self activateBundle:candidate]; break; }
    [self updateChrome];
}
- (void)closeBundle:(NSString *)bundle {
    MWWindowView *window=_windows[bundle];
    if(!window) return;
    MWRect r=window.model.maximized ? window.model.restoreFrame : window.model.frame;
    [MWPreferences.shared saveFrame:CGRectMake(r.x,r.y,r.width,r.height) forBundle:bundle viewport:_viewport];
    [MWPreferences.shared saveResizeMode:window.model.maximized ? window.model.restoreResizeMode : window.model.resizeMode forBundle:bundle];
    [window close]; [_windows removeObjectForKey:bundle]; [_order removeObject:bundle];
    for(NSString *candidate in [[_order copy] reverseObjectEnumerator])
        if(!_windows[candidate].hidden) { [self activateBundle:candidate]; break; }
    [self updateChrome];
}
- (void)closeAllWindows { for(NSString *bundle in [_order copy]) [self closeBundle:bundle]; }
- (void)setHostVisible:(BOOL)visible {
    MWLog(@"workspace.visibility",@{@"visible":@(visible),@"floating":@(_floating),@"windows":@(_windows.count)});
    _hostHidden=!visible;
    if(!visible) { [_bubble cancelInteraction]; [self closePanel]; }
    for(MWWindowView *window in _windows.allValues) [window setHostVisible:visible];
}
- (void)openSettings {
    [self closePanel];
    if(self.presentedViewController) return;
    [MWKeyboardFocus.shared focusHostWindow:self.view.window reason:@"settings"];
    MWSettingsController *settings=[MWSettingsController new];
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
- (void)showMessage:(NSString *)message {
    if(!message.length || self.presentedViewController) return;
    UIAlertController *alert=[UIAlertController alertControllerWithTitle:@"初春星河" message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"知道了" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}
- (void)dealloc { [[NSNotificationCenter defaultCenter] removeObserver:self]; }
@end
