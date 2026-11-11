// SPDX-License-Identifier: Apache-2.0
#import "MWWorkspaceCoordinator.h"
#import "MWWorkspaceController.h"
#import "MWAppPickerController.h"
#import "MWPreferences.h"
#import "../Diagnostics/MWDiagnostics.h"
#import "../Platform/MWFloatingHost.h"
#import "../Platform/MWApplicationActivation.h"
#import "../Platform/MWKeyboardFocus.h"
#import "../Platform/MWRuntimeDiagnostics.h"
#import "../Core/MWSearchHandoff.h"
#import "../Core/MWAppearanceState.h"
#include <dlfcn.h>

static NSString *MWAppearanceString(const char *symbol) {
    // Optional UIKit exports: absent on an OS version means scene-trait fallback.
    const void *address=dlsym(RTLD_DEFAULT,symbol);
    if(!address) return nil;
    id value=*(__unsafe_unretained id const *)address;
    return [value isKindOfClass:NSString.class] ? value : nil;
}
static UIUserInterfaceStyle MWAppearanceValue(id value) {
    if(![value isKindOfClass:NSNumber.class]) return UIUserInterfaceStyleUnspecified;
    double style=[value doubleValue];
    return style==UIUserInterfaceStyleLight || style==UIUserInterfaceStyleDark ? (UIUserInterfaceStyle)style : UIUserInterfaceStyleUnspecified;
}

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
    BOOL _inputSuspendedOverlay;
    MWSearchHandoff _inputState;
    BOOL _inputPending;
    MWAppearanceState _appearanceState;
    uint64_t _appearanceRevision;
    NSString *_systemAppearanceKey;
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
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(inputApplicationActivated:) name:UIApplicationDidBecomeActiveNotification object:nil];
        [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(refreshAppearance) name:MWPreferencesDidChangeNotification object:nil];
        NSString *styleNotification=MWAppearanceString("UIApplicationSystemwideUserInterfaceStyleChangedNotification");
        _systemAppearanceKey=MWAppearanceString("UIApplicationSystemwideUserInterfaceStyleKey");
        if(styleNotification) [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(systemAppearanceChanged:) name:styleNotification object:nil];
        MWLog(@"appearance.system_observer",@{@"notificationAvailable":@(styleNotification!=nil),@"keyAvailable":@(_systemAppearanceKey!=nil)});
    }
    return self;
}
- (void)applyAppearance {
    NSAssert(NSThread.isMainThread,@"Window appearance is main-thread owned");
    UIUserInterfaceStyle preference=MWPreferences.shared.appearance;
    UIUserInterfaceStyle floating=(UIUserInterfaceStyle)MWAppearanceOverride(&_appearanceState,(int)preference);
    BOOL changed=(_applicationWindow && _applicationWindow.overrideUserInterfaceStyle!=preference) ||
        (_floatingWindow && _floatingWindow.overrideUserInterfaceStyle!=floating);
    // The ordinary scene continues to inherit UIKit's system style. A locally
    // hosted scene may retain the creation snapshot, so update its window from
    // the system event explicitly. Never read an overridden window as the source.
    if(_applicationWindow.overrideUserInterfaceStyle!=preference) _applicationWindow.overrideUserInterfaceStyle=preference;
    if(_floatingWindow.overrideUserInterfaceStyle!=floating) _floatingWindow.overrideUserInterfaceStyle=floating;
    if(changed) MWLog(@"appearance.applied",@{@"preference":@(preference),@"system":@(_appearanceState.systemStyle),
        @"floatingOverride":@(floating),@"floatingAttached":@(_floatingWindow!=nil)});
}
- (uint64_t)nextAppearanceRevision {
    // Notifications may arrive off-main. State and windows remain main-owned;
    // only observation numbering is shared across those queues.
    @synchronized(self) { return ++_appearanceRevision; }
}
- (void)refreshAppearanceFromCurrentScene:(UIWindowScene *)scene {
    NSAssert(NSThread.isMainThread,@"Appearance snapshots are main-thread owned");
    uint64_t revision=[self nextAppearanceRevision];
    UIUserInterfaceStyle system=MWAppearanceValue(MWRuntimeIntegerValue(UIApplication.sharedApplication,@"_systemUserInterfaceStyle"));
    MWAppearanceObserve(&_appearanceState,revision,(int)system,(int)scene.traitCollection.userInterfaceStyle,scene!=nil);
    [self applyAppearance];
}
- (void)refreshAppearance {
    if(!NSThread.isMainThread) { dispatch_async(dispatch_get_main_queue(),^{[self refreshAppearance];}); return; }
    UIWindowScene *scene=_applicationWindow.windowScene;
    BOOL current=scene && (scene.activationState==UISceneActivationStateForegroundActive || scene.activationState==UISceneActivationStateForegroundInactive);
    [self refreshAppearanceFromCurrentScene:current ? scene : nil];
}
- (void)systemAppearanceChanged:(NSNotification *)notification {
    uint64_t revision=[self nextAppearanceRevision];
    UIUserInterfaceStyle style=MWAppearanceValue(_systemAppearanceKey ? notification.userInfo[_systemAppearanceKey] : nil);
    // A later lifecycle snapshot may be applied before this block executes.
    // Carry both value and observation revision, never replay an older style.
    void (^apply)(void)=^{
        if(revision<=self->_appearanceState.appliedRevision) return;
        if(style!=UIUserInterfaceStyleUnspecified) {
            MWAppearanceObserve(&self->_appearanceState,revision,(int)style,0,false);
            [self applyAppearance];
        }
        else [self refreshAppearance];
    };
    if(NSThread.isMainThread) apply(); else dispatch_async(dispatch_get_main_queue(),apply);
}
- (void)sceneAppearanceChanged:(UIWindowScene *)scene {
    // This entry is for new traits or entering foreground, not every geometry
    // callback: unchanged traits from an old background scene are not current.
    if(scene && scene==_applicationWindow.windowScene) [self refreshAppearanceFromCurrentScene:scene];
    else [self applyAppearance];
}
- (void)attachApplicationWindow:(UIWindow *)window {
    if(_applicationWindow && _applicationWindow!=window) _applicationWindow.rootViewController=nil;
    _applicationWindow=window;
    if(_floatingWindow) window.rootViewController=[MWFloatingPlaceholder new];
    else { _workspace.floating=NO; window.rootViewController=_workspace; [_workspace setHostVisible:!_inputPending]; }
    // A newly connected ordinary scene supplies a fresh fallback even before
    // UIKit advances its activationState to foreground.
    [self refreshAppearanceFromCurrentScene:window.windowScene];
    if(_inputPending) [self tryPresentApplicationSearch];
}
- (void)attachFloatingWindow:(UIWindow *)window {
    // There is exactly one workspace and therefore one bundle-ID registry.
    [_workspace dismissViewControllerAnimated:NO completion:nil];
    if(_applicationWindow.rootViewController==_workspace) _applicationWindow.rootViewController=[MWFloatingPlaceholder new];
    _floatingWindow=window; _workspace.floating=YES; window.rootViewController=_workspace;
    [self refreshAppearance];
    [_workspace setHostVisible:YES];
}
- (void)returnToApplication:(NSNotification *)notification {
    (void)notification;
    [self finishApplicationSearch:nil];
    if(_floatingWindow.rootViewController==_workspace) _floatingWindow.rootViewController=nil;
    _floatingWindow=nil; _workspace.floating=NO;
    _applicationWindow.rootViewController=_workspace;
    [self refreshAppearance];
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
    if(visible) [self refreshAppearance];
    if(window.rootViewController==_workspace) [_workspace setHostVisible:visible && !_inputPending];
}
- (void)floatingVisibility:(NSNotification *)notification {
    if(_inputPending && notification.object==_floatingWindow) {
        if(MWFloatingHost.shared.isLocked) {
            MWLog(@"search.handoff_cancelled",@{@"reason":@"locked"});
            [self finishApplicationSearch:nil];
            return;
        }
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
    if(_inputPending || !_floatingWindow || !MWFloatingHost.shared.ready || MWFloatingHost.shared.isLocked) return;
    _inputQuery=[query copy]; _inputSelection=[selection copy];
    [self beginNormalInput];
}
- (void)beginNormalInput {
    UIWindow *window=_applicationWindow;
    _inputPending=YES;
    uint64_t generation=MWSearchHandoffBegin(&_inputState,NSProcessInfo.processInfo.systemUptime);
    _inputSuspendedOverlay=_floatingWindow && MWFloatingHost.shared.ready;
    if(_inputSuspendedOverlay) [MWFloatingHost.shared setSearchInputSuspended:YES];
    [_workspace setHostVisible:NO];
    MWLog(@"search.handoff_begin",@{@"mainWindow":@(window!=nil),@"mainSceneState":@(window ? window.windowScene.activationState : UISceneActivationStateUnattached)});
    if(!MWSearchHandoffCurrent(&_inputState,generation)) return;
    if(window && window.windowScene.activationState==UISceneActivationStateForegroundActive) {
        [self tryPresentApplicationSearch];
    } else {
        NSError *error=nil;
        BOOL accepted=MWRequestOwnApplicationForeground(&error);
        MWSearchHandoffLaunchResult(&_inputState,generation,accepted,NSProcessInfo.processInfo.systemUptime);
        MWLog(@"search.application_open",@{@"accepted":@(accepted),@"error":MWErrorFields(error)});
    }
    [self pollApplicationSearch:generation];
}
- (void)pollApplicationSearch:(uint64_t)generation {
    if(!_inputPending || !MWSearchHandoffCurrent(&_inputState,generation)) return;
    [self tryPresentApplicationSearch];
    if(!_inputPending || !MWSearchHandoffCurrent(&_inputState,generation) || _inputState.phase==MWSearchActive) return;
    __weak typeof(self) weakSelf=self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(0.1*NSEC_PER_SEC)),dispatch_get_main_queue(),^{
        [weakSelf pollApplicationSearch:generation];
    });
}
- (void)requestInputScene:(uint64_t)generation {
    UISceneSession *session=_applicationWindow.windowScene.session;
    if(!session) {
        MWLog(@"search.main_scene_request_unavailable",@{@"reason":@"normal scene not connected"});
        return; // LaunchServices can still connect the normal scene before deadline.
    }
    UISceneActivationRequestOptions *options=[UISceneActivationRequestOptions new];
    options.requestingScene=_floatingWindow.windowScene;
    MWLog(@"search.main_scene_activation",@{@"mainSceneState":@(_applicationWindow.windowScene.activationState)});
    __weak typeof(self) weakSelf=self;
    [[UIApplication sharedApplication] requestSceneSessionActivation:session userActivity:nil options:options errorHandler:^(NSError *error){
        dispatch_async(dispatch_get_main_queue(),^{
            MWWorkspaceCoordinator *coordinator=weakSelf;
            if(!coordinator || !coordinator->_inputPending || !MWSearchHandoffCurrent(&coordinator->_inputState,generation)) return;
            MWLog(@"search.main_scene_failed",MWErrorFields(error));
            // A late scene error must not cancel an accepted app-open request
            // or a picker already presented by the activation notification.
        });
    }];
}
- (void)inputSceneActivated:(NSNotification *)notification {
    if(notification.object==_applicationWindow.windowScene) [self tryPresentApplicationSearch];
}
- (void)inputApplicationActivated:(NSNotification *)notification {
    (void)notification; [self refreshAppearance]; [self tryPresentApplicationSearch];
}
- (void)inputSceneBackgrounded:(NSNotification *)notification {
    if(_inputPending && _inputNavigation && notification.object==_applicationWindow.windowScene) {
        MWLog(@"search.handoff_cancelled",@{@"reason":@"main scene backgrounded"});
        [self finishApplicationSearch:nil];
    }
}
- (void)tryPresentApplicationSearch {
    if(!_inputPending) return;
    uint64_t generation=_inputState.generation;
    UIWindow *window=_applicationWindow;
    UIViewController *presenter=window.rootViewController;
    BOOL foreground=window && window.windowScene.activationState==UISceneActivationStateForegroundActive;
    BOOL presenterReady=presenter && !presenter.presentedViewController && !presenter.isBeingDismissed;
    MWSearchAction action=MWSearchHandoffObserve(&_inputState,generation,NSProcessInfo.processInfo.systemUptime,foreground,presenterReady);
    if(action==MWSearchActivateScene) { [self requestInputScene:generation]; return; }
    if(action==MWSearchAbort) {
        MWLog(@"search.handoff_timeout",@{@"mainWindow":@(window!=nil),@"mainSceneState":@(window ? window.windowScene.activationState : UISceneActivationStateUnattached),
            @"presenterBusy":@(presenter.presentedViewController!=nil)});
        [self finishApplicationSearch:nil];
        [_workspace showMessage:@"主应用暂时未能打开，已恢复工作台。可从主屏幕打开初春星河后重试。"];
        return;
    }
    if(action!=MWSearchPresent) return;
    [_applicationWindow makeKeyAndVisible];
    __weak typeof(self) weakSelf=self;
    MWAppPickerController *picker=[MWAppPickerController new]; picker.initialQuery=_inputQuery; picker.automaticallyFocusSearch=YES;
    __weak MWAppPickerController *weakPicker=picker;
    picker.selectionHandler=^(MWApplication *application){
        MWWorkspaceCoordinator *coordinator=weakSelf;
        if(coordinator && coordinator->_inputPending && MWSearchHandoffCurrent(&coordinator->_inputState,generation) && coordinator->_inputNavigation.viewControllers.firstObject==weakPicker)
            [coordinator finishApplicationSearch:application];
    };
    picker.cancellationHandler=^{
        MWWorkspaceCoordinator *coordinator=weakSelf;
        if(coordinator && coordinator->_inputPending && MWSearchHandoffCurrent(&coordinator->_inputState,generation) && coordinator->_inputNavigation.viewControllers.firstObject==weakPicker)
            [coordinator finishApplicationSearch:nil];
    };
    [self presentNormalInputController:picker presenter:presenter generation:generation];
}
- (void)invalidateNormalInput:(UIViewController *)controller {
    if([controller isKindOfClass:MWAppPickerController.class]) {
        MWAppPickerController *picker=(MWAppPickerController *)controller;
        [picker invalidateSearch]; picker.selectionHandler=nil; picker.cancellationHandler=nil; picker.searchFallbackHandler=nil;
    }
}
- (void)presentNormalInputController:(UIViewController *)controller presenter:(UIViewController *)presenter generation:(uint64_t)generation {
    _inputNavigation=[[UINavigationController alloc] initWithRootViewController:controller];
    _inputNavigation.modalPresentationStyle=UIModalPresentationFullScreen;
    __weak typeof(self) weakSelf=self;
    __weak UIViewController *weakController=controller;
    __weak UINavigationController *weakNavigation=_inputNavigation;
    [presenter presentViewController:_inputNavigation animated:YES completion:^{
        MWWorkspaceCoordinator *coordinator=weakSelf;
        UINavigationController *navigation=weakNavigation;
        if(!coordinator || !coordinator->_inputPending || !MWSearchHandoffCurrent(&coordinator->_inputState,generation) ||
           coordinator->_inputNavigation!=navigation) {
            [coordinator invalidateNormalInput:weakController];
            // This presentation may complete after lock/timeout/cancellation.
            // Dismiss only its owned controller, never a subsequent search.
            if(navigation && navigation.presentingViewController.presentedViewController==navigation && !navigation.isBeingDismissed)
                [navigation dismissViewControllerAnimated:NO completion:nil];
            return;
        }
        if(MWSearchHandoffPresented(&coordinator->_inputState,generation))
            MWLog(@"search.main_scene_presented",@{@"keyWindow":@(coordinator->_applicationWindow.isKeyWindow),
                @"mainSceneState":@(coordinator->_applicationWindow.windowScene.activationState)});
    }];
}
- (void)finishApplicationSearch:(MWApplication *)application {
    if(!_inputPending) return;
    _inputPending=NO; MWSearchHandoffFinish(&_inputState);
    void (^selection)(MWApplication *)=_inputSelection; _inputSelection=nil; _inputQuery=nil;
    UINavigationController *navigation=_inputNavigation; _inputNavigation=nil;
    [self invalidateNormalInput:navigation.viewControllers.firstObject];
    if(navigation) [MWKeyboardFocus.shared releaseForWindow:_applicationWindow];
    if(navigation.isBeingPresented) {
        // The presentation completion also checks ownership for the case where
        // UIKit no longer accepts additional transition completion blocks.
        __weak UINavigationController *weakNavigation=navigation;
        [navigation.transitionCoordinator animateAlongsideTransition:nil completion:^(id<UIViewControllerTransitionCoordinatorContext> context){
            (void)context; UINavigationController *owned=weakNavigation;
            if(owned && owned.presentingViewController.presentedViewController==owned && !owned.isBeingDismissed)
                [owned dismissViewControllerAnimated:NO completion:nil];
        }];
    } else if(navigation && navigation.presentingViewController.presentedViewController==navigation && !navigation.isBeingDismissed) {
        [navigation dismissViewControllerAnimated:NO completion:nil];
    }
    if(_inputSuspendedOverlay) { _inputSuspendedOverlay=NO; [MWFloatingHost.shared setSearchInputSuspended:NO]; }
    else if(!_floatingWindow)
        [_workspace setHostVisible:_applicationWindow.windowScene.activationState==UISceneActivationStateForegroundActive];
    MWLog(@"search.main_scene_finished",@{@"selected":@(application!=nil)});
    if(application && selection) selection(application);
}
@end

