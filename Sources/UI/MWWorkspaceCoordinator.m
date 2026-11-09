// SPDX-License-Identifier: Apache-2.0
#import "MWWorkspaceCoordinator.h"
#import "MWWorkspaceController.h"
#import "MWAppPickerController.h"
#import "../Diagnostics/MWDiagnostics.h"
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
    UINavigationController *_inputNavigation;
    NSString *_inputQuery;
    void (^_inputSelection)(MWApplication *);
    NSUInteger _inputGeneration;
    BOOL _inputPending;
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
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(inputSceneActivated:) name:UISceneDidActivateNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(inputSceneBackgrounded:) name:UISceneDidEnterBackgroundNotification object:nil];
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
    [self finishApplicationSearch:nil];
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
    if(window==_applicationWindow && _inputPending) [self finishApplicationSearch:nil];
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
    if(_inputPending && notification.object==_floatingWindow) {
        _floatingWindow.hidden=YES;
        return;
    }
    [self setWindow:notification.object visible:[notification.userInfo[@"visible"] boolValue]];
}
- (void)floatingReady:(NSNotification *)notification {
    UIWindow *window=notification.object;
    if(MWFloatingHost.shared.ready && window==MWFloatingHost.shared.floatingWindow) [self attachFloatingWindow:window];
}
- (void)presentApplicationSearchWithQuery:(NSString *)query selection:(void (^)(MWApplication *))selection {
    if(_inputPending) return;
    UIWindow *window=_applicationWindow;
    if(!window.windowScene.session || window.rootViewController.presentedViewController) {
        [_workspace showMessage:@"请先从主屏幕打开初春星河，再使用应用内搜索。"]; return;
    }
    _inputPending=YES; _inputQuery=[query copy]; _inputSelection=[selection copy];
    NSUInteger generation=++_inputGeneration;
    [MWFloatingHost.shared setSearchInputSuspended:YES]; [_workspace setHostVisible:NO];
    __weak typeof(self) weakSelf=self;
    [[UIApplication sharedApplication] requestSceneSessionActivation:window.windowScene.session userActivity:nil options:nil errorHandler:^(NSError *error){
        dispatch_async(dispatch_get_main_queue(),^{
            MWWorkspaceCoordinator *coordinator=weakSelf;
            if(!coordinator || generation!=coordinator->_inputGeneration || !coordinator->_inputPending) return;
            MWLog(@"search.main_scene_failed",MWErrorFields(error));
            [coordinator finishApplicationSearch:nil]; [coordinator.workspace showMessage:@"系统未能打开主应用输入界面，请从主屏幕打开初春星河后搜索。"];
        });
    }];
    [self tryPresentApplicationSearch];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,5*NSEC_PER_SEC),dispatch_get_main_queue(),^{
        MWWorkspaceCoordinator *coordinator=weakSelf;
        if(coordinator && generation==coordinator->_inputGeneration && coordinator->_inputPending && !coordinator->_inputNavigation) {
            [coordinator finishApplicationSearch:nil];
            [coordinator.workspace showMessage:@"主应用输入界面激活超时，请从主屏幕打开后搜索。"];
        }
    });
}
- (void)inputSceneActivated:(NSNotification *)notification {
    if(notification.object==_applicationWindow.windowScene) [self tryPresentApplicationSearch];
}
- (void)inputSceneBackgrounded:(NSNotification *)notification {
    if(_inputPending && _inputNavigation && notification.object==_applicationWindow.windowScene) [self finishApplicationSearch:nil];
}
- (void)tryPresentApplicationSearch {
    if(!_inputPending || _inputNavigation || _applicationWindow.windowScene.activationState!=UISceneActivationStateForegroundActive) return;
    [_applicationWindow makeKeyAndVisible];
    MWAppPickerController *picker=[MWAppPickerController new]; picker.initialQuery=_inputQuery; picker.automaticallyFocusSearch=YES;
    __weak typeof(self) weakSelf=self;
    NSUInteger generation=_inputGeneration;
    __weak MWAppPickerController *weakPicker=picker;
    picker.selectionHandler=^(MWApplication *application){
        MWWorkspaceCoordinator *coordinator=weakSelf;
        if(coordinator && coordinator->_inputPending && generation==coordinator->_inputGeneration && coordinator->_inputNavigation.viewControllers.firstObject==weakPicker)
            [coordinator finishApplicationSearch:application];
    };
    picker.cancellationHandler=^{
        MWWorkspaceCoordinator *coordinator=weakSelf;
        if(coordinator && coordinator->_inputPending && generation==coordinator->_inputGeneration && coordinator->_inputNavigation.viewControllers.firstObject==weakPicker)
            [coordinator finishApplicationSearch:nil];
    };
    _inputNavigation=[[UINavigationController alloc] initWithRootViewController:picker];
    [_applicationWindow.rootViewController presentViewController:_inputNavigation animated:YES completion:nil];
    MWLog(@"search.main_scene_presented",@{@"session":_applicationWindow.windowScene.session.persistentIdentifier ?: @"none"});
}
- (void)finishApplicationSearch:(MWApplication *)application {
    if(!_inputPending) return;
    _inputPending=NO; _inputGeneration++;
    void (^selection)(MWApplication *)=_inputSelection; _inputSelection=nil; _inputQuery=nil;
    MWAppPickerController *picker=(MWAppPickerController *)_inputNavigation.viewControllers.firstObject;
    picker.selectionHandler=nil; picker.cancellationHandler=nil; picker.searchFallbackHandler=nil;
    [_inputNavigation.presentingViewController dismissViewControllerAnimated:NO completion:nil]; _inputNavigation=nil;
    [MWFloatingHost.shared setSearchInputSuspended:NO];
    MWLog(@"search.main_scene_finished",@{@"selected":@(application!=nil)});
    if(application && selection) selection(application);
}
@end

