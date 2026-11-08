// SPDX-License-Identifier: Apache-2.0
#import "MWWorkspaceController.h"
#import "MWWindowView.h"
#import "MWAppPickerController.h"
#import "MWSettingsController.h"
#import "MWPreferences.h"
#import "MWEdgeHandle.h"
#import "../Diagnostics/MWDiagnostics.h"
#import "../Platform/MWFloatingHost.h"

@interface MWCanvas : UIView
@property(nonatomic) BOOL passThrough;
@end
@implementation MWCanvas
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *hit=[super hitTest:point withEvent:event];
    MWWindowView *window=nil;
    for(UIView *ancestor=hit;ancestor && ancestor!=self;ancestor=ancestor.superview)
        if([ancestor isKindOfClass:MWWindowView.class]) { window=(MWWindowView *)ancestor; break; }
    if(window && !window.active && event.type==UIEventTypeTouches) {
        __weak MWWindowView *weakWindow=window;
        dispatch_async(dispatch_get_main_queue(),^{ if(weakWindow.activateHandler) weakWindow.activateHandler(); });
    }
    return self.passThrough && hit==self ? nil : hit;
}
@end

@implementation MWWorkspaceController {
    MWCanvas *_canvas;
    NSMutableDictionary<NSString *,MWWindowView *> *_windows;
    NSMutableArray<NSString *> *_order;
    UILabel *_heading, *_subtitle, *_emptyTitle, *_emptyHint;
    UIButton *_add, *_settings;
    MWEdgeHandle *_bubble;
    UIVisualEffectView *_shelf;
    UIScrollView *_shelfScroll;
    UIStackView *_shelfItems;
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
    _heading=[self label:@"UiharuX" size:32 weight:UIFontWeightBold color:UIColor.labelColor];
    _subtitle=[self label:@"银河工作台  /  MILKYWAY" size:12 weight:UIFontWeightSemibold color:UIColor.secondaryLabelColor];
    _emptyTitle=[self label:@"让应用，各得其所。" size:24 weight:UIFontWeightSemibold color:UIColor.labelColor];
    _emptyHint=[self label:@"打开一个应用小窗\n拖动标题栏移动，双击标题栏放大。" size:15 weight:UIFontWeightRegular color:UIColor.secondaryLabelColor];
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
    _bubble.activationHandler=^{[weakSelf openPicker];};
    _bubble.settingsHandler=^{[weakSelf openSettings];};
    _shelf=[[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemChromeMaterial]];
    _shelf.layer.cornerRadius=22; _shelf.clipsToBounds=YES; [self.view addSubview:_shelf];
    _shelfScroll=[UIScrollView new]; _shelfScroll.showsHorizontalScrollIndicator=NO; [_shelf.contentView addSubview:_shelfScroll];
    _shelfItems=[UIStackView new]; _shelfItems.axis=UILayoutConstraintAxisHorizontal; _shelfItems.spacing=8; [_shelfScroll addSubview:_shelfItems];
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
    if(self.isViewLoaded) { [self updateChrome]; [self.view setNeedsLayout]; }
}
- (void)applyPreferences {
    self.overrideUserInterfaceStyle=MWPreferences.shared.appearance;
    self.view.window.overrideUserInterfaceStyle=MWPreferences.shared.appearance;
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
    _shelf.frame=CGRectMake(left,bounds.size.height-safe.bottom-72,width,58);
    _shelfScroll.frame=_shelf.bounds;
    CGSize fitting=[_shelfItems systemLayoutSizeFittingSize:UILayoutFittingCompressedSize];
    _shelfItems.frame=CGRectMake(10,7,MAX(1,fitting.width),44);
    _shelfScroll.contentSize=CGSizeMake(fitting.width+20,58);
    [_bubble applyViewport:CGRectMake(0,safe.top+12,bounds.size.width,MAX(48,bounds.size.height-safe.top-safe.bottom-24))];
    CGFloat top=_floating ? safe.top+8 : safe.top+100;
    CGFloat bottom=safe.bottom+(_shelf.hidden ? 16 : 84);
    CGRect viewport=CGRectMake(safe.left+8,top,MAX(1,bounds.size.width-safe.left-safe.right-16),MAX(1,bounds.size.height-top-bottom));
    if(!CGRectEqualToRect(_viewport,viewport)) {
        _viewport=viewport;
        for(MWWindowView *window in _windows.allValues) [window applyViewport:viewport];
    }
}
- (void)updateChrome {
    if(!self.isViewLoaded) return;
    self.view.backgroundColor=_floating ? UIColor.clearColor : UIColor.systemGroupedBackgroundColor;
    _canvas.passThrough=_floating;
    _heading.hidden=_subtitle.hidden=_settings.hidden=_floating;
    _emptyTitle.hidden=_emptyHint.hidden=_add.hidden=_floating || _windows.count>0;
    _bubble.hidden=!_floating && _windows.count==0;
    [self rebuildShelf];
    for(UIView *v in @[_bubble,_shelf]) [self.view bringSubviewToFront:v];
    [self.view setNeedsLayout];
}
- (void)rebuildShelf {
    for(UIView *view in _shelfItems.arrangedSubviews) { [_shelfItems removeArrangedSubview:view]; [view removeFromSuperview]; }
    for(NSString *bundle in _order) {
        MWWindowView *window=_windows[bundle];
        if(window.model.state!=MWWindowMinimized) continue;
        UIButton *item=[UIButton buttonWithType:UIButtonTypeSystem];
        if(@available(iOS 15.0,*)) {
            UIButtonConfiguration *config=[UIButtonConfiguration tintedButtonConfiguration];
            config.title=window.application.name; config.cornerStyle=UIButtonConfigurationCornerStyleCapsule;
            config.image=[UIImage systemImageNamed:@"arrow.up.forward.app"];
            config.imagePadding=6; item.configuration=config;
        } else {
            [item setTitle:window.application.name forState:UIControlStateNormal];
            item.contentEdgeInsets=UIEdgeInsetsMake(0,16,0,16); item.backgroundColor=UIColor.tertiarySystemBackgroundColor; item.layer.cornerRadius=20;
        }
        item.accessibilityLabel=[NSString stringWithFormat:@"恢复 %@",window.application.name];
        __weak typeof(self) weakSelf=self;
        [item addAction:[UIAction actionWithHandler:^(__kindof UIAction *action) { (void)action; [weakSelf restoreBundle:bundle]; }] forControlEvents:UIControlEventTouchUpInside];
        [_shelfItems addArrangedSubview:item];
    }
    _shelf.hidden=_shelfItems.arrangedSubviews.count==0;
}
- (void)openPicker {
    if(self.presentedViewController) return;
    MWAppPickerController *picker=[MWAppPickerController new];
    __weak typeof(self) weakSelf=self;
    picker.selectionHandler=^(MWApplication *app) { [weakSelf openApplication:app]; };
    UINavigationController *nav=[[UINavigationController alloc] initWithRootViewController:picker];
    nav.modalPresentationStyle=UIModalPresentationPageSheet;
    [self presentViewController:nav animated:!MWPreferences.shared.reduceMotion completion:nil];
}
- (void)openApplication:(MWApplication *)application {
    MWLog(@"workspace.open",@{@"bundle":application.bundleIdentifier,@"floating":@(_floating)});
    MWWindowView *existing=_windows[application.bundleIdentifier];
    if(existing) { [self restoreBundle:application.bundleIdentifier]; return; }
    if(_windows.count>=4) { [self showMessage:@"Alpha 版本最多同时保留 4 个窗口，请先关闭一个。"] ; return; }
    [self.view layoutIfNeeded];
    CGFloat offset=(_windows.count%3)*20;
    CGRect frame=CGRectMake(_viewport.origin.x+offset,_viewport.origin.y+offset,MIN(340,_viewport.size.width),MIN(460,_viewport.size.height));
    frame=[MWPreferences.shared frameForBundle:application.bundleIdentifier viewport:_viewport fallback:frame];
    MWWindowView *window=[[MWWindowView alloc] initWithApplication:application frame:frame];
    NSString *bundle=application.bundleIdentifier;
    _windows[bundle]=window; [_order addObject:bundle];
    __weak typeof(self) weakSelf=self;
    window.activateHandler=^{[weakSelf activateBundle:bundle];};
    window.closeHandler=^{[weakSelf closeBundle:bundle];};
    window.minimizeHandler=^{[weakSelf minimizeBundle:bundle];};
    window.geometryHandler=^(CGRect geometry) {
        MWWorkspaceController *controller=weakSelf;
        if(controller) [MWPreferences.shared saveFrame:geometry forBundle:bundle viewport:controller->_viewport];
    };
    window.stateHandler=^{ [weakSelf updateChrome]; };
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
    [self.view bringSubviewToFront:_bubble]; [self.view bringSubviewToFront:_shelf];
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
    [window close]; [_windows removeObjectForKey:bundle]; [_order removeObject:bundle];
    for(NSString *candidate in [[_order copy] reverseObjectEnumerator])
        if(!_windows[candidate].hidden) { [self activateBundle:candidate]; break; }
    [self updateChrome];
}
- (void)closeAllWindows { for(NSString *bundle in [_order copy]) [self closeBundle:bundle]; }
- (void)setHostVisible:(BOOL)visible {
    MWLog(@"workspace.visibility",@{@"visible":@(visible),@"floating":@(_floating),@"windows":@(_windows.count)});
    _hostHidden=!visible;
    for(MWWindowView *window in _windows.allValues) [window setHostVisible:visible];
}
- (void)openSettings {
    if(self.presentedViewController) return;
    MWSettingsController *settings=[MWSettingsController new];
    __weak typeof(self) weakSelf=self;
    settings.floatingHandler=^(BOOL enabled) {
        NSError *error=nil;
        if(![MWFloatingHost.shared setEnabled:enabled fromScene:weakSelf.view.window.windowScene error:&error]) [weakSelf showMessage:error.localizedDescription];
    };
    [self presentViewController:[[UINavigationController alloc] initWithRootViewController:settings] animated:YES completion:nil];
}
- (void)floatingFailed:(NSNotification *)notification { [self showMessage:[notification.object localizedDescription]]; }
- (void)showMessage:(NSString *)message {
    if(!message.length || self.presentedViewController) return;
    UIAlertController *alert=[UIAlertController alertControllerWithTitle:@"UiharuX" message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"知道了" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}
- (void)dealloc { [[NSNotificationCenter defaultCenter] removeObserver:self]; }
@end
