// SPDX-License-Identifier: Apache-2.0
#import "MWWorkspaceCoordinator.h"
#import "MWWorkspaceController.h"
#import "../Platform/MWFloatingHost.h"

@interface MWFloatingPlaceholder : UIViewController
@end
@implementation MWFloatingPlaceholder
- (void)viewDidLoad {
    [super viewDidLoad]; self.view.backgroundColor=UIColor.systemGroupedBackgroundColor;
    UILabel *label=[UILabel new]; label.text=@"工作台已移到浮窗"; label.textAlignment=NSTextAlignmentCenter;
    label.font=[UIFont systemFontOfSize:22 weight:UIFontWeightSemibold];
    UIButton *button=[UIButton buttonWithType:UIButtonTypeSystem];
    [button setTitle:@"返回应用内工作台" forState:UIControlStateNormal];
    [button addTarget:self action:@selector(returnToApplication) forControlEvents:UIControlEventTouchUpInside];
    UIStackView *stack=[[UIStackView alloc] initWithArrangedSubviews:@[label,button]];
    stack.axis=UILayoutConstraintAxisVertical; stack.spacing=24; stack.translatesAutoresizingMaskIntoConstraints=NO;
    [self.view addSubview:stack];
    [NSLayoutConstraint activateConstraints:@[
        [stack.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [stack.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],
        [stack.widthAnchor constraintLessThanOrEqualToAnchor:self.view.safeAreaLayoutGuide.widthAnchor constant:-32],
        [button.heightAnchor constraintGreaterThanOrEqualToConstant:44]
    ]];
}
- (void)returnToApplication { [MWFloatingHost.shared setEnabled:NO fromScene:self.view.window.windowScene error:nil]; }
@end

@implementation MWWorkspaceCoordinator {
    __weak UIWindow *_applicationWindow;
    __weak UIWindow *_floatingWindow;
}
+ (instancetype)shared {
    static MWWorkspaceCoordinator *coordinator; static dispatch_once_t once;
    dispatch_once(&once,^{coordinator=[self new];}); return coordinator;
}
- (instancetype)init {
    if((self=[super init])) {
        _workspace=[MWWorkspaceController new];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(returnToApplication:) name:MWFloatingHostWillStopNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(floatingVisibility:) name:MWFloatingHostVisibilityNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(floatingReady:) name:MWFloatingHostDidBecomeReadyNotification object:nil];
    }
    return self;
}
- (void)attachApplicationWindow:(UIWindow *)window {
    if(_applicationWindow && _applicationWindow!=window) _applicationWindow.rootViewController=nil;
    _applicationWindow=window;
    if(_floatingWindow) window.rootViewController=[MWFloatingPlaceholder new];
    else { _workspace.floating=NO; window.rootViewController=_workspace; [_workspace setHostVisible:YES]; }
}
- (void)attachFloatingWindow:(UIWindow *)window {
    // There is exactly one workspace and therefore one bundle-ID registry.
    [_workspace dismissViewControllerAnimated:NO completion:nil];
    if(_applicationWindow.rootViewController==_workspace) _applicationWindow.rootViewController=[MWFloatingPlaceholder new];
    _floatingWindow=window; _workspace.floating=YES; window.rootViewController=_workspace;
    [_workspace setHostVisible:YES];
}
- (void)returnToApplication:(NSNotification *)notification {
    (void)notification;
    if(_floatingWindow.rootViewController==_workspace) _floatingWindow.rootViewController=nil;
    _floatingWindow=nil; _workspace.floating=NO;
    _applicationWindow.rootViewController=_workspace;
    BOOL visible=_applicationWindow && _applicationWindow.windowScene.activationState!=UISceneActivationStateBackground
        && _applicationWindow.windowScene.activationState!=UISceneActivationStateUnattached;
    [_workspace setHostVisible:visible];
    if(visible) [_applicationWindow makeKeyAndVisible];
}
- (void)detachWindow:(UIWindow *)window {
    if(!window) return;
    if(window==_floatingWindow) [self returnToApplication:nil];
    if(window==_applicationWindow) {
        if(window.rootViewController==_workspace) window.rootViewController=nil;
        _applicationWindow=nil;
    }
    if(!_applicationWindow && !_floatingWindow) [_workspace closeAllWindows];
}
- (void)setWindow:(UIWindow *)window visible:(BOOL)visible {
    if(window.rootViewController==_workspace) [_workspace setHostVisible:visible];
}
- (void)floatingVisibility:(NSNotification *)notification {
    [self setWindow:notification.object visible:[notification.userInfo[@"visible"] boolValue]];
}
- (void)floatingReady:(NSNotification *)notification {
    UIWindow *window=notification.object;
    if(MWFloatingHost.shared.ready && window==MWFloatingHost.shared.floatingWindow) [self attachFloatingWindow:window];
}
@end

