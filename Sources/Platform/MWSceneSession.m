// SPDX-License-Identifier: Apache-2.0
// Scene lifecycle adapted from FrontBoardAppLauncher; redesigned cancellation,
// identity, cleanup and failure handling. Explicit entry resets the selected
// process before hosting; ordinary teardown does not terminate other apps.
#import "MWSceneSession.h"
#import "MWPrivate.h"
#include <signal.h>
#include <errno.h>
#import "../Diagnostics/MWDiagnostics.h"
#import "MWKeyboardFocus.h"
#import "MWSceneInputEnvironment.h"
#import "MWRuntimeDiagnostics.h"
#import "MWApplicationProfile.h"
#import "MWBackgroundLease.h"
#import "MWSceneLayerDiagnostics.h"
#import "MWGuestTermination.h"
#import "../Core/MWGuestPolicy.h"
#import "../Core/MWSceneGeometry.h"
#import "../Core/MWGuestLaunchGate.h"
#import "../Core/MWRuntimeTypes.h"
#import "../Core/MWNativeHandoff.h"
#import <objc/runtime.h>
#import <objc/message.h>
#include <string.h>

static BOOL MWGuestMethod(id object,SEL selector,char result,const char *args) {
    if(!object || ![object respondsToSelector:selector]) return NO;
    Method method=class_getInstanceMethod(object_getClass(object),selector);
    if(!method || method_getNumberOfArguments(method)!=strlen(args)+2) return NO;
    char type[64]={0};method_getReturnType(method,type,sizeof(type));
    if(!MWObjCTypeMatches(type,result)) return NO;
    for(unsigned i=0;i<strlen(args);i++) {
        method_getArgumentType(method,i+2,type,sizeof(type));
        if(!MWObjCTypeMatches(type,args[i])) return NO;
    }
    return YES;
}
static id MWSceneForeground(UIApplicationSceneSettings *settings) {
    SEL getter=@selector(isForeground); // Declared accessor, not the property name.
    @try {
        if(!MWGuestMethod(settings,getter,'B',"") && !MWGuestMethod(settings,getter,'c',"")) return @"unavailable";
        return @([settings isForeground]);
    } @catch(NSException *exception) { (void)exception; return @"exception"; }
}

@implementation MWSceneSession {
    FBApplicationProcessLaunchTransaction *_transaction;
    FBScene *_scene;
    _UIScenePresenter *_presenter;
    RBSProcessHandle *_process;
    MWSceneInputEnvironment *_inputEnvironment;
    dispatch_source_t _monitor;
    void (^_completion)(NSError *);
    BOOL _started, _closed, _visible;
    BOOL _observingInput, _inputKnown, _inputActive;
    NSUInteger _generation;
    CGSize _size;
    UIInterfaceOrientation _orientation;
    MWNativeHandoff _nativeHandoff;
    void (^_nativeCompletion)(NSError *);
    BOOL _cleanupFailed;
    UIEdgeInsets _safeInsets;
    BOOL _diagnosticCapabilitiesRecorded;
    BOOL _clientConnectionObserved;
    NSUInteger _renderEventCount;
    NSDictionary *_lastRenderSnapshot;
    MWBackgroundLease *_backgroundLease;
    BOOL _keepAliveRequested;
    NSDictionary *_lastInputLayers;
    NSUInteger _inputLayerSamples;
    CFTimeInterval _lastInputLayerTime;
    void (^_userCloseAfterLaunch)(NSError *);
    RBSProcessHandle *_ownedProcessForUserClose;
    MWGuestLaunchGate _launchGate;
    BOOL _resetInProgress;
}

- (instancetype)initWithBundleIdentifier:(NSString *)bundleIdentifier {
    if((self=[super init])) {
        _bundleIdentifier=[bundleIdentifier copy];
        _sceneIdentifier=[@"io.github.airskotex.harugalaxy.guest." stringByAppendingString:NSUUID.UUID.UUIDString];
        _visible=YES; _orientation=UIInterfaceOrientationPortrait;
    }
    return self;
}

- (UIView *)contentView { return _presenter.presentationView; }

- (void)startWithSize:(CGSize)size completion:(void (^)(NSError *))completion {
    NSAssert(NSThread.isMainThread,@"Scene sessions are main-thread owned");
    if(_started || _closed) { completion(MWError(10,@"该窗口会话已结束，请重新打开。")); return; }
    if(MWGuestResetPending(self.bundleIdentifier)) { completion(MWError(73,@"该应用的旧进程尚未结束，请稍后重新打开。")); return; }
    _started=YES; _size=size; _completion=[completion copy];
    MWLog(@"guest.application_profile",MWApplicationProfile(self.bundleIdentifier));
    MWLog(@"guest.launch_requested",@{@"bundle":self.bundleIdentifier,@"scene":self.sceneIdentifier,@"width":@(size.width),@"height":@(size.height)});
    NSString *issue=MWSceneCapabilityIssue();
    if(issue) { [self fail:MWError(11,issue)]; return; }
    [self beginProcessLaunch];
}
- (void)beginProcessLaunch {
    if(_closed || !_completion) return;
    NSUInteger generation=++_generation;
    MWLog(@"guest.process_launch_phase",@{@"bundle":self.bundleIdentifier,@"phase":@(_launchGate.phase),@"generation":@(generation)});
    __weak typeof(self) weakSelf=self;
    @try {
        RBSProcessIdentity *identity=[PrivClass(RBSProcessIdentity) identityForEmbeddedApplicationIdentifier:self.bundleIdentifier];
        FBProcessManager *manager=[PrivClass(FBProcessManager) sharedInstance];
        _transaction=[[PrivClass(FBApplicationProcessLaunchTransaction) alloc] initWithProcessIdentity:identity executionContextProvider:^id {
            FBMutableProcessExecutionContext *context=[PrivClass(FBMutableProcessExecutionContext) new];
            context.identity=identity; context.environment=@{}; context.launchIntent=4;
            return [manager launchProcessWithContext:context];
        }];
        if(!_transaction) { [self fail:MWError(12,@"无法创建应用启动请求。")]; return; }
        [_transaction setCompletionBlock:^{
            dispatch_async(dispatch_get_main_queue(), ^{
                MWSceneSession *strongSelf=weakSelf;
                if(!strongSelf || strongSelf->_closed || strongSelf->_generation!=generation || !strongSelf->_completion) return;
                [strongSelf attachProcess:identity];
            });
        }];
        [_transaction begin];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,12*NSEC_PER_SEC),dispatch_get_main_queue(),^{
            MWSceneSession *strongSelf=weakSelf;
            if(strongSelf && !strongSelf->_closed && strongSelf->_generation==generation && strongSelf->_completion)
                [strongSelf fail:MWError(13,@"应用启动超时。请先正常打开该应用一次，再重试小窗。")];
        });
    } @catch(NSException *exception) {
        [self fail:MWError(14,[NSString stringWithFormat:@"应用启动失败：%@",exception.reason])];
    }
}

- (void)attachProcess:(RBSProcessIdentity *)identity {
    @try {
        NSError *error=nil;
        RBSProcessPredicate *predicate=[PrivClass(RBSProcessPredicate) predicateMatchingIdentity:identity];
        _process=[PrivClass(RBSProcessHandle) handleForPredicate:predicate error:&error];
        MWLog(@"guest.process",@{@"bundle":self.bundleIdentifier,@"pid":@(_process.pid),@"error":MWErrorFields(error)});
        if(!_process || _process.pid<=0) { [self fail:error ?: MWError(15,@"未能取得应用进程。")]; return; }
        _ownedProcessForUserClose=_process;
        if(_userCloseAfterLaunch) {
            void (^closed)(NSError *)=_userCloseAfterLaunch; _userCloseAfterLaunch=nil;
            [self closeAfterUserRequest:closed]; return;
        }
        MWGuestLaunchAction action=MWGuestLaunchResolved(&_launchGate,_process.pid);
        if(action==MWGuestLaunchReset) { [self resetBeforeHosting]; return; }
        if(action==MWGuestLaunchFail) { [self fail:MWError(74,@"系统仍返回旧应用进程，未创建重复小窗。请手动结束原应用后重试。")]; return; }
        if(action!=MWGuestLaunchAttach) return;
        [[PrivClass(FBProcessManager) sharedInstance] registerProcessForAuditToken:_process.auditToken];
        FBSMutableSceneDefinition *definition=[PrivClass(FBSMutableSceneDefinition) definition];
        definition.identity=[PrivClass(FBSSceneIdentity) identityForIdentifier:self.sceneIdentifier];
        definition.clientIdentity=[PrivClass(FBSSceneClientIdentity) identityForProcessIdentity:_process.identity];
        definition.specification=[PrivClass(UIApplicationSceneSpecification) specification];
        FBSMutableSceneParameters *parameters=[PrivClass(FBSMutableSceneParameters) parametersForSpecification:definition.specification];
        UIMutableApplicationSceneSettings *settings=[PrivClass(UIMutableApplicationSceneSettings) new];
        settings.displayConfiguration=UIScreen.mainScreen.displayConfiguration;
        settings.foreground=_visible;
        settings.frame=[self nativeSceneFrame];
        settings.interfaceOrientation=_orientation;
        [self applyDeviceOrientation:settings];
        settings.level=1;
        settings.canShowAlerts=YES;
        settings.persistenceIdentifier=self.sceneIdentifier;
        settings.peripheryInsets=UIEdgeInsetsZero;
        [self applySafeInsets:settings];
        settings.statusBarDisabled=YES;
        parameters.settings=settings;
        UIMutableApplicationSceneClientSettings *client=[PrivClass(UIMutableApplicationSceneClientSettings) new];
        client.interfaceOrientation=_orientation;
        parameters.clientSettings=client;
        _scene=[[PrivClass(FBSceneManager) sharedInstance] createSceneWithDefinition:definition initialParameters:parameters];
        if(_scene && MWKeyboardFocus.shared.supportsGuestHosting)
            _inputEnvironment=[[MWSceneInputEnvironment alloc] initWithScene:_scene identifier:self.sceneIdentifier processIdentifier:_process.pid];
        [self observeGuestInput];
        _presenter=[_scene.uiPresentationManager createPresenterWithIdentifier:self.sceneIdentifier];
        if(!_scene || !_presenter) {
            [self fail:MWError(16,@"此应用未提供可显示的场景，可能不支持小窗。")]; return;
        }
        [_presenter activate];
        if(!_presenter.presentationView) { [self fail:MWError(16,@"应用未提供可显示的小窗视图。")]; return; }
        if(!_visible) [_presenter deactivate];
        [self updateBackgroundLease];
        [MWKeyboardFocus.shared registerGuest:self.sceneIdentifier processIdentifier:_process.pid scene:_scene];
        MWLog(@"guest.presenter_ready",@{@"bundle":self.bundleIdentifier,@"scene":self.sceneIdentifier,@"pid":@(_process.pid),@"note":@"presenter object only; first frame not observed"});
        _transaction=nil;
        void (^completion)(NSError *)=_completion; _completion=nil;
        if(completion) completion(nil);
        [self observeRendering:@"presenter_attached"];
        NSUInteger renderGeneration=_generation;
        __weak typeof(self) renderSelf=self;
        for(NSNumber *delay in @[@0.5,@2.0,@6.0,@12.0]) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(delay.doubleValue*NSEC_PER_SEC)),dispatch_get_main_queue(),^{
                MWSceneSession *session=renderSelf;
                if(session && !session->_closed && !session->_nativeCompletion && session->_generation==renderGeneration)
                    [session observeRendering:[NSString stringWithFormat:@"after_%g",delay.doubleValue]];
            });
        }
        [self readGuestInputState];
        if(!_closed) [self startMonitoring];
    } @catch(NSException *exception) {
        [self fail:MWError(17,[NSString stringWithFormat:@"建立小窗失败：%@",exception.reason])];
    }
}
- (void)resetBeforeHosting {
    _resetInProgress=YES; ++_generation; // Invalidate the first launch deadline.
    [_transaction setCompletionBlock:nil]; _transaction=nil;
    if(self.startupStatusHandler) self.startupStatusHandler(@"正在结束原应用播放…\n随后重新打开小窗");
    __weak typeof(self) weakSelf=self;
    MWResetGuestForHosting(self.bundleIdentifier,_process,^{
        MWSceneSession *session=weakSelf;
        if(!session || session->_closed) return;
        if(session.startupStatusHandler) session.startupStatusHandler(@"系统仍在结束旧进程\n可从系统多任务界面手动结束原应用");
        if(session.closeProgressHandler) session.closeProgressHandler();
    },^(NSError *error) {
        MWSceneSession *session=weakSelf;
        if(!session) return;
        session->_resetInProgress=NO;
        if(session->_userCloseAfterLaunch) {
            void (^closed)(NSError *)=session->_userCloseAfterLaunch; session->_userCloseAfterLaunch=nil;
            [session close]; closed(error); return;
        }
        MWGuestLaunchAction action=MWGuestLaunchResetFinished(&session->_launchGate,error==nil);
        if(session->_closed || action==MWGuestLaunchIgnore) return;
        if(action==MWGuestLaunchFail) { [session fail:error ?: MWError(74,@"无法结束旧进程，已停止创建小窗。")]; return; }
        session->_process=nil;
        if(session.startupStatusHandler) session.startupStatusHandler(@"原应用已结束，正在打开小窗…");
        [session beginProcessLaunch];
    });
}
- (void)observeGuestInput {
    SEL add=NSSelectorFromString(@"addObserver:"),remove=NSSelectorFromString(@"removeObserver:");
    if(!MWGuestMethod(_scene,add,'v',"@") || !MWGuestMethod(_scene,remove,'v',"@")) {
        MWLog(@"keyboard.guest_observer_unavailable",@{@"scene":self.sceneIdentifier}); return;
    }
    @try {
        _observingInput=YES;
        ((void(*)(id,SEL,id))objc_msgSend)(_scene,add,self);
    } @catch(NSException *exception) {
        MWLog(@"keyboard.guest_observer_failed",@{@"reason":exception.reason ?: @"unknown"});
    }
}
- (void)scene:(id)scene didUpdateClientSettingsWithDiff:(id)diff oldClientSettings:(id)old transitionContext:(id)context {
    (void)diff; (void)old; (void)context;
    __weak typeof(self) weakSelf=self;
    dispatch_async(dispatch_get_main_queue(),^{
        MWSceneSession *session=weakSelf;
        if(session && !session->_closed && session->_scene==scene) {
            [session readGuestInputState];
            if(session.presentationGeometryHandler) session.presentationGeometryHandler();
        }
    });
}
- (void)scene:(id)scene didCompleteUpdateWithContext:(id)context error:(NSError *)error {
    (void)context;
    __weak typeof(self) weakSelf=self;
    dispatch_async(dispatch_get_main_queue(),^{
        MWSceneSession *session=weakSelf;
        if(!session || session->_closed || session->_scene!=scene) return;
        if(error) MWLog(@"guest.geometry_update_failed",@{@"scene":session.sceneIdentifier,@"error":MWErrorFields(error)});
        if(session.presentationGeometryHandler) session.presentationGeometryHandler();
    });
}
- (void)scene:(id)scene clientDidConnect:(id)client {
    (void)client;
    __weak typeof(self) weakSelf=self;
    dispatch_async(dispatch_get_main_queue(),^{
        MWSceneSession *session=weakSelf;
        if(!session || session->_closed || session->_scene!=scene) return;
        session->_clientConnectionObserved=YES; [session observeRendering:@"client_connected"];
    });
}
- (void)sceneContentStateDidChange:(id)scene {
    __weak typeof(self) weakSelf=self;
    dispatch_async(dispatch_get_main_queue(),^{
        MWSceneSession *session=weakSelf;
        if(session && !session->_closed && session->_scene==scene && !session->_nativeCompletion)
            [session observeRendering:@"content_state_changed"];
    });
}
- (NSDictionary *)renderDiagnosticSnapshot {
    id manager=MWRuntimeObjectValue(_scene,@"layerManager");
    id layers=MWRuntimeObjectValue(manager,@"layers");
    NSArray *list=[layers isKindOfClass:NSOrderedSet.class] ? [layers array] :
        ([layers isKindOfClass:NSSet.class] ? [layers allObjects] : ([layers isKindOfClass:NSArray.class] ? layers : nil));
    NSUInteger nonKeyboard=0; BOOL typesKnown=list.count<=64;
    for(id layer in list) {
        if(!typesKnown) break;
        id keyboard=MWRuntimeBoolValue(layer,@"isKeyboardLayer");
        id proxy=MWRuntimeBoolValue(layer,@"isKeyboardProxyLayer");
        if(![keyboard isKindOfClass:NSNumber.class] || ![proxy isKindOfClass:NSNumber.class]) { typesKnown=NO; break; }
        if(![keyboard boolValue] && ![proxy boolValue]) nonKeyboard++;
    }
    return @{@"sceneValid":MWRuntimeBoolValue(_scene,@"isValid"),@"legacyScene":MWRuntimeBoolValue(_scene,@"_isLegacy"),
        @"contentState":MWRuntimeIntegerValue(_scene,@"contentState"),@"clientConnectionObserved":@(_clientConnectionObserved),
        @"layerCount":list ? @(list.count) : @"unavailable",
        @"nonKeyboardLayerCount":list && typesKnown ? @(nonKeyboard) : @"unavailable",
        @"presenterActive":MWRuntimeBoolValue(_presenter,@"isActive"),@"presenterHosting":MWRuntimeBoolValue(_presenter,@"isHosting"),
        @"foreground":MWSceneForeground(MWRuntimeObjectValue(_scene,@"settings")),@"visibleRequested":@(_visible),
        @"width":@(_size.width),@"height":@(_size.height)};
}
- (void)observeRendering:(NSString *)reason {
    [self observeInputLayers:reason];
    if(_closed || !_scene || _renderEventCount>=24) return;
    NSDictionary *snapshot=[self renderDiagnosticSnapshot];
    if([reason isEqual:@"content_state_changed"] && [snapshot isEqual:_lastRenderSnapshot]) return;
    _lastRenderSnapshot=snapshot; _renderEventCount++;
    MWLog(@"guest.render_probe",@{@"bundle":self.bundleIdentifier,@"scene":self.sceneIdentifier,@"reason":reason,
        @"ordinal":@(_renderEventCount),@"render":snapshot,@"meaning":@"layer_registration_only_not_pixels"});
}
- (void)observeInputLayers:(NSString *)reason {
    if(_closed || !_scene || !_visible || _nativeCompletion || _inputLayerSamples>=60) return;
    CFTimeInterval now=CACurrentMediaTime();
    if(_lastInputLayerTime>0 && now-_lastInputLayerTime<0.3) return;
    _lastInputLayerTime=now;
    NSDictionary *layers=MWSceneLayerSnapshot(_scene,_presenter);
    if([layers isEqual:_lastInputLayers]) return;
    _lastInputLayers=layers; _inputLayerSamples++;
    MWLog(@"keyboard.guest_layers",@{@"scene":self.sceneIdentifier,@"bundle":self.bundleIdentifier,@"reason":reason,
        @"ordinal":@(_inputLayerSamples),@"layers":layers,@"focus":[MWKeyboardFocus.shared diagnosticSnapshotWithCapabilities:NO]});
    // Capture bottom probes while the guest is still present, rather than
    // only after settings/export have changed focus or collected the windows.
    [NSNotificationCenter.defaultCenter postNotificationName:MWKeyboardDiagnosticSampleNotification object:self
        userInfo:@{@"reason":@"guest_layer_change",@"capabilities":@NO}];
}
- (void)readGuestInputState {
    if(_closed || !_scene) return;
    @try {
        SEL settings=NSSelectorFromString(@"clientSettings"),active=NSSelectorFromString(@"systemInputActive");
        if(!MWGuestMethod(_scene,settings,'@',"")) return;
        id client=((id(*)(id,SEL))objc_msgSend)(_scene,settings);
        if(!MWGuestMethod(client,active,'B',"") && !MWGuestMethod(client,active,'c',"")) {
            if(!_inputKnown) MWLog(@"keyboard.guest_state_unavailable",@{@"scene":self.sceneIdentifier});
            _inputKnown=YES; return;
        }
        BOOL wantsInput=((BOOL(*)(id,SEL))objc_msgSend)(client,active);
        if(_inputKnown && _inputActive==wantsInput) return;
        _inputKnown=YES; _inputActive=wantsInput;
        MWLog(@"keyboard.guest_input_state",@{@"scene":self.sceneIdentifier,@"pid":@(_process.pid),@"systemInputActive":@(wantsInput)});
        if(wantsInput && _visible && self.inputRequestHandler) self.inputRequestHandler();
    } @catch(NSException *exception) {
        MWLog(@"keyboard.guest_state_unavailable",@{@"scene":self.sceneIdentifier,@"reason":exception.reason ?: @"unknown"});
    }
}
- (NSDictionary *)inputDiagnosticSnapshotWithCapabilities:(BOOL)capabilities {
    id client=MWRuntimeObjectValue(_scene,@"clientSettings");
    id settings=MWRuntimeObjectValue(_scene,@"settings");
    NSString *safeSelector=@"safeAreaInsetsPortrait";
    if(_orientation==UIInterfaceOrientationLandscapeLeft) safeSelector=@"safeAreaInsetsLandscapeLeft";
    else if(_orientation==UIInterfaceOrientationLandscapeRight) safeSelector=@"safeAreaInsetsLandscapeRight";
    else if(_orientation==UIInterfaceOrientationPortraitUpsideDown) safeSelector=@"safeAreaInsetsPortraitUpsideDown";
    NSMutableDictionary *snapshot=[@{@"bundle":self.bundleIdentifier,@"scene":self.sceneIdentifier,
        @"pid":@(_process.pid),@"closed":@(_closed),@"visibleRequested":@(_visible),@"observingInput":@(_observingInput),
        @"keepAliveRequested":@(_keepAliveRequested),@"keepAliveGranted":@(self.keepAliveGranted),
        @"inputKnown":@(_inputKnown),@"lastInputActive":@(_inputActive),
        @"systemInputActive":MWRuntimeBoolValue(client,@"systemInputActive"),
        @"foreground":MWSceneForeground(settings),@"sceneActive":MWRuntimeBoolValue(_scene,@"isActive"),
        @"presenterActive":MWRuntimeBoolValue(_presenter,@"isActive"),@"presenterHosting":MWRuntimeBoolValue(_presenter,@"isHosting"),
        @"safeAreaRequested":@[@(_safeInsets.top),@(_safeInsets.left),@(_safeInsets.bottom),@(_safeInsets.right)],
        @"safeAreaReported":MWRuntimeInsetsValue(settings,safeSelector),@"orientation":@(_orientation),
        @"nativeFrameReported":MWRuntimeRectValue(settings,@"frame"),
        @"orientationReported":MWRuntimeIntegerValue(settings,@"interfaceOrientation"),
        @"clientOrientation":MWRuntimeIntegerValue(client,@"interfaceOrientation"),
        @"clientSupportedOrientations":MWRuntimeIntegerValue(client,@"supportedInterfaceOrientations"),
        @"render":[self renderDiagnosticSnapshot],
        @"inputLayers":MWSceneLayerSnapshot(_scene,_presenter),
        @"inputEnvironment":_inputEnvironment ? [_inputEnvironment diagnosticSnapshot] : @{@"registered":@NO}} mutableCopy];
    if(capabilities || (!_diagnosticCapabilitiesRecorded && _scene)) {
        _diagnosticCapabilitiesRecorded=(_scene!=nil);
        id uiClient=MWRuntimeObjectValue(_scene,@"uiClientSettings");
        snapshot[@"uiSystemInputActive"]=MWRuntimeBoolValue(uiClient,@"systemInputActive");
        snapshot[@"methods"]=@{
        @"inputActive":MWRuntimeMethodSnapshot(client,@"systemInputActive"),@"sceneToken":MWRuntimeMethodSnapshot(_scene,@"identityToken"),
        @"uiInputActive":MWRuntimeMethodSnapshot(uiClient,@"systemInputActive"),
        @"deactivate":MWRuntimeMethodSnapshot(_scene,@"deactivate:"),
        @"settingsUpdate":MWRuntimeMethodSnapshot(_scene,@"updateSettings:withTransitionContext:completion:")};
    }
    return snapshot;
}

- (void)startMonitoring {
    __weak typeof(self) weakSelf=self;
    _monitor=dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER,0,0,dispatch_get_main_queue());
    dispatch_source_set_timer(_monitor,dispatch_time(DISPATCH_TIME_NOW,2*NSEC_PER_SEC),2*NSEC_PER_SEC,NSEC_PER_SEC/2);
    dispatch_source_set_event_handler(_monitor,^{
        MWSceneSession *strongSelf=weakSelf;
        if(!strongSelf || strongSelf->_closed) return;
        pid_t pid=strongSelf->_process.pid;
        if(pid<=0 || (kill(pid,0)==-1 && errno==ESRCH))
            [strongSelf fail:MWError(18,@"应用已退出，可重新打开小窗。")];
        else if(strongSelf->_visible) { [strongSelf readGuestInputState]; [strongSelf observeInputLayers:@"periodic_change_check"]; }
    });
    dispatch_resume(_monitor);
}

- (void)applySafeInsets:(UIMutableApplicationSceneSettings *)settings {
    // Each field is expressed in that orientation's scene coordinates.
    // Reset unused orientations so an old offscreen edge cannot survive rotation.
    settings.safeAreaInsetsPortrait=UIEdgeInsetsZero;
    settings.safeAreaInsetsPortraitUpsideDown=UIEdgeInsetsZero;
    settings.safeAreaInsetsLandscapeLeft=UIEdgeInsetsZero;
    settings.safeAreaInsetsLandscapeRight=UIEdgeInsetsZero;
    switch(_orientation) {
        case UIInterfaceOrientationLandscapeLeft: settings.safeAreaInsetsLandscapeLeft=_safeInsets; break;
        case UIInterfaceOrientationLandscapeRight: settings.safeAreaInsetsLandscapeRight=_safeInsets; break;
        case UIInterfaceOrientationPortraitUpsideDown: settings.safeAreaInsetsPortraitUpsideDown=_safeInsets; break;
        default: settings.safeAreaInsetsPortrait=_safeInsets; break;
    }
}
- (void)updateSize:(CGSize)size orientation:(UIInterfaceOrientation)orientation safeAreaInsets:(UIEdgeInsets)insets {
    if(_closed || _nativeCompletion || !isfinite(size.width) || !isfinite(size.height) || size.width<1 || size.height<1) return;
    _size=size;
    _safeInsets=insets;
    if(orientation!=UIInterfaceOrientationUnknown) _orientation=orientation;
    if(!_scene) return;
    MWTrace(@"guest.logical_geometry",@{@"bundle":self.bundleIdentifier,@"width":@(size.width),@"height":@(size.height),@"orientation":@(orientation),
        @"nativeFrame":NSStringFromCGRect([self nativeSceneFrame]),
        @"safeInsets":@[@(insets.top),@(insets.left),@(insets.bottom),@(insets.right)]});
    @try {
        UIInterfaceOrientation resolved=_orientation;
        [_scene updateSettingsWithBlock:^(UIMutableApplicationSceneSettings *settings) {
            settings.frame=[self nativeSceneFrame]; settings.interfaceOrientation=resolved;
            [self applyDeviceOrientation:settings];
            [self applySafeInsets:settings];
        }];
    } @catch(NSException *exception) {
        [self fail:MWError(19,[NSString stringWithFormat:@"更新小窗尺寸失败：%@",exception.reason])];
    }
}
- (CGRect)nativeSceneFrame {
    MWRect native=MWSceneFrameForInterface((MWRect){0,0,_size.width,_size.height},(int)_orientation);
    return CGRectMake(native.x,native.y,native.width,native.height);
}

- (void)setVisible:(BOOL)visible {
    [self setVisible:visible keepAlive:NO];
}
- (BOOL)keepAliveRequested { return _keepAliveRequested; }
- (BOOL)keepAliveGranted { return _keepAliveRequested && _backgroundLease.valid; }
- (void)updateBackgroundLease {
    if(!_keepAliveRequested || _closed || _nativeCompletion || _visible) {
        [_backgroundLease invalidate]; _backgroundLease=nil; return;
    }
    if(!_process || _process.pid<=0 || _backgroundLease) return;
    _backgroundLease=[MWBackgroundLease new]; NSError *error=nil;
    BOOL requested=[_backgroundLease acquireForProcess:_process.pid name:@"HaruGalaxy minimized guest" error:&error];
    MWLog(@"guest.keepalive",@{@"bundle":self.bundleIdentifier,@"pid":@(_process.pid),
        @"requested":@(requested),@"granted":@(_backgroundLease.valid),@"error":MWErrorFields(error)});
}
- (void)setVisible:(BOOL)visible keepAlive:(BOOL)keepAlive {
    if(_closed || _nativeCompletion) return;
    _keepAliveRequested=keepAlive && !visible;
    BOOL visibilityChanged=_visible!=visible;
    _visible=visible;
    [self updateBackgroundLease];
    if(!visibilityChanged) return;
    if(!visible) [self releaseKeyboardFocus];
    MWTrace(@"guest.visibility",@{@"bundle":self.bundleIdentifier,@"visible":@(visible)});
    @try {
        [_scene updateSettingsWithBlock:^(UIMutableApplicationSceneSettings *settings) { settings.foreground=visible; }];
        if(visible) [_presenter activate]; else [_presenter deactivate];
    } @catch(NSException *exception) {
        [self fail:MWError(20,[NSString stringWithFormat:@"更新窗口状态失败：%@",exception.reason])];
    }
}
- (void)applyDeviceOrientation:(UIMutableApplicationSceneSettings *)settings {
    SEL device=NSSelectorFromString(@"setDeviceOrientation:"),enabled=NSSelectorFromString(@"setDeviceOrientationEventsEnabled:");
    if(MWGuestMethod(settings,device,'v',"q"))
        ((void(*)(id,SEL,NSInteger))objc_msgSend)(settings,device,MWDeviceOrientationForInterface((int)_orientation));
    if(MWGuestMethod(settings,enabled,'v',"B") || MWGuestMethod(settings,enabled,'v',"c"))
        ((void(*)(id,SEL,BOOL))objc_msgSend)(settings,enabled,YES);
}
- (void)requestKeyboardFocusInWindow:(UIWindow *)window {
    if(!_closed && _visible && _scene && _presenter.presentationView.window==window)
        [MWKeyboardFocus.shared focusGuest:self.sceneIdentifier inWindow:window];
}
- (void)refreshKeyboardFocusInWindow:(UIWindow *)window {
    if(!_closed && _visible && _scene && _presenter.presentationView.window==window)
        [MWKeyboardFocus.shared refreshGuest:self.sceneIdentifier inWindow:window];
}
- (void)releaseKeyboardFocus { [MWKeyboardFocus.shared releaseGuest:self.sceneIdentifier]; }

- (void)fail:(NSError *)error {
    if(_closed) return;
    MWLog(@"guest.failed",@{@"bundle":self.bundleIdentifier,@"scene":self.sceneIdentifier,@"error":MWErrorFields(error)});
    void (^completion)(NSError *)=_completion;
    void (^failure)(NSError *)=self.failureHandler;
    void (^userClose)(NSError *)=_userCloseAfterLaunch; _userCloseAfterLaunch=nil;
    [self close];
    if(userClose) { userClose(error); return; }
    if(completion) completion(error); else if(failure) failure(error);
}

- (void)close {
    if(_closed) return;
    void (^nativeCompletion)(NSError *)=_nativeCompletion; _nativeCompletion=nil;
    MWNativeHandoffCancel(&_nativeHandoff);
    MWGuestLaunchCancel(&_launchGate);
    MWLog(@"guest.close",@{@"bundle":self.bundleIdentifier,@"scene":self.sceneIdentifier});
    _closed=YES; ++_generation; _completion=nil; self.failureHandler=nil; self.inputRequestHandler=nil;
    self.presentationGeometryHandler=nil; self.startupStatusHandler=nil;
    [self tearDown];
    if(nativeCompletion) nativeCompletion(MWError(63,@"原应用切换已取消，未发送打开请求。"));
}
- (void)closeAfterUserRequest:(void (^)(NSError *))completion {
    if(_userCloseAfterLaunch) { completion(MWError(72,@"该应用正在关闭。")); return; }
    if(_resetInProgress) {
        _userCloseAfterLaunch=[completion copy]; MWGuestLaunchCancel(&_launchGate);
        self.failureHandler=nil; self.inputRequestHandler=nil; return;
    }
    if(!_process && _transaction && _completion && !_closed) {
        // Do not cancel launch bookkeeping before learning its exact handle:
        // otherwise a late launch could survive the user's Close action.
        _userCloseAfterLaunch=[completion copy]; self.failureHandler=nil; self.inputRequestHandler=nil;
        _visible=NO; _keepAliveRequested=NO; return;
    }
    id process=_process ?: _ownedProcessForUserClose; // Retain the original handle across local teardown.
    // Device feedback shows local scene release does not establish seamless
    // native relaunch. Do NOT wait for native handoff before termination:
    // that would allow an app opened from Home to reuse the old process.
    [self close];
    MWLog(@"guest.user_close_cleanup",@{@"bundle":self.bundleIdentifier,@"cleanupFailed":@(_cleanupFailed)});
    MWEndOwnedGuest(process,self.closeProgressHandler,completion);
}

- (MWNativeRoute)nativeHandoffRoute {
    id manager=[PrivClass(FBSceneManager) sharedInstance];
    BOOL cleanup=MWGuestMethod(manager,NSSelectorFromString(@"destroyScene:withTransitionContext:"),'v',"@@") &&
        MWGuestMethod(manager,NSSelectorFromString(@"sceneWithIdentifier:"),'@',"@") &&
        (!_presenter || (MWGuestMethod(_presenter,@selector(deactivate),'v',"") &&
            MWGuestMethod(_presenter,@selector(invalidate),'v',"")));
    id settings=MWRuntimeObjectValue(_scene,@"settings");
    id mutableSettings=MWGuestMethod(settings,@selector(mutableCopy),'@',"") ? [settings mutableCopy] : nil;
    SEL foregroundSetter=NSSelectorFromString(@"setForeground:");
    BOOL settingsRoute=MWGuestMethod(_scene,NSSelectorFromString(@"updateSettings:withTransitionContext:completion:"),'v',"@@@") &&
        [MWSceneForeground(settings) isKindOfClass:NSNumber.class] &&
        (MWGuestMethod(mutableSettings,foregroundSetter,'v',"B") || MWGuestMethod(mutableSettings,foregroundSetter,'v',"c"));
    return MWNativeHandoffChoose(MWGuestMethod(_scene,NSSelectorFromString(@"deactivate:"),'v',"@"),settingsRoute,cleanup);
}
- (NSError *)originalApplicationHandoffIssue {
    if(MWGuestResetPending(self.bundleIdentifier) ||
       (_started && !_closed && !MWGuestLaunchAllowsHandoff(&_launchGate,_resetInProgress)))
        return MWError(73,@"该应用正在重建小窗，请等待完成后再切回原应用。");
    if(_nativeCompletion) return MWError(63,@"该窗口正在切换，请稍后再试。");
    if(_cleanupFailed || [MWKeyboardFocus.shared hasPendingCleanup])
        return MWError(66,@"小窗输入清理未完成，已保留当前窗口。请导出诊断并重启初春星河。");
    if(_closed || !_scene) return nil;
    @try {
        MWNativeRoute route=[self nativeHandoffRoute];
        MWLog(@"native_handoff.capabilities",@{@"scene":self.sceneIdentifier,@"route":@(route),
            @"deactivate":MWRuntimeMethodSnapshot(_scene,@"deactivate:"),
            @"settingsUpdate":MWRuntimeMethodSnapshot(_scene,@"updateSettings:withTransitionContext:completion:"),
            @"foregroundGetter":MWRuntimeMethodSnapshot(MWRuntimeObjectValue(_scene,@"settings"),NSStringFromSelector(@selector(isForeground))),
            @"sceneLookup":MWRuntimeMethodSnapshot([PrivClass(FBSceneManager) sharedInstance],@"sceneWithIdentifier:")});
        return route==MWNativeRouteUnavailable ? MWError(64,@"当前系统没有可用的应用切换接口，已保留小窗。请导出诊断；也可先关闭小窗，再从主屏幕打开应用。") : nil;
    } @catch(NSException *exception) {
        MWLog(@"native_handoff.preflight_failed",@{@"scene":self.sceneIdentifier,@"exception":exception.name ?: @"unknown"});
        return MWError(64,@"无法检查应用切换接口，已保留小窗。请导出诊断。");
    }
}
- (void)closeForOriginalApplication:(void (^)(NSError *))completion {
    NSError *issue=[self originalApplicationHandoffIssue];
    if(issue) { completion(issue); return; }
    if(_closed) { completion(nil); return; }
    MWNativeRoute route=MWNativeRouteUnavailable;
    @try { if(_scene) route=[self nativeHandoffRoute]; }
    @catch(NSException *exception) {
        completion(MWError(64,@"场景接口检查失败，未发送打开请求。")); return;
    }
    _nativeCompletion=[completion copy]; _visible=NO; _generation++;
    [_backgroundLease invalidate]; _backgroundLease=nil; _keepAliveRequested=NO;
    _completion=nil; self.failureHandler=nil; self.inputRequestHandler=nil;
    [self releaseKeyboardFocus];
    uint64_t generation=MWNativeHandoffBegin(&_nativeHandoff,NSProcessInfo.processInfo.systemUptime);
    if(!_scene) {
        MWNativeHandoffDeactivated(&_nativeHandoff,generation);
        [self pollNativeHandoff:generation]; return;
    }
    MWLog(@"native_handoff.deactivating",@{@"bundle":self.bundleIdentifier,@"scene":self.sceneIdentifier,@"route":@(route)});
    __weak typeof(self) weakSelf=self;
    @try {
        id active=MWRuntimeBoolValue(_scene,@"isActive");
        id foreground=MWSceneForeground(MWRuntimeObjectValue(_scene,@"settings"));
        if([foreground isKindOfClass:NSNumber.class] && ![foreground boolValue] &&
           ([active isKindOfClass:NSNumber.class] && ![active boolValue])) {
            MWNativeHandoffDeactivated(&_nativeHandoff,generation);
            [self pollNativeHandoff:generation]; return;
        }
        dispatch_block_t acknowledged=^{
            dispatch_async(dispatch_get_main_queue(),^{
                MWSceneSession *session=weakSelf;
                if(!session || !session->_nativeCompletion || generation!=session->_nativeHandoff.generation) return;
                id current=MWSceneForeground(MWRuntimeObjectValue(session->_scene,@"settings"));
                BOOL accepted=route==MWNativeRouteDeactivate ||
                    ([current isKindOfClass:NSNumber.class] && ![current boolValue]);
                MWLog(@"native_handoff.background_acknowledged",@{@"scene":session.sceneIdentifier,@"route":@(route),
                    @"foreground":current,@"accepted":@(accepted)});
                if(accepted && MWNativeHandoffDeactivated(&session->_nativeHandoff,generation))
                    MWLog(@"native_handoff.deactivated",@{@"scene":session.sceneIdentifier,@"route":@(route)});
            });
        };
        if(route==MWNativeRouteDeactivate) {
            ((void(*)(id,SEL,id))objc_msgSend)(_scene,NSSelectorFromString(@"deactivate:"),[acknowledged copy]);
        } else {
            id settings=[MWRuntimeObjectValue(_scene,@"settings") mutableCopy];
            SEL setter=NSSelectorFromString(@"setForeground:");
            if(!MWGuestMethod(settings,setter,'v',"B") && !MWGuestMethod(settings,setter,'v',"c"))
                @throw [NSException exceptionWithName:@"MWSceneSettingsABI" reason:@"foreground setter unavailable" userInfo:nil];
            ((void(*)(id,SEL,BOOL))objc_msgSend)(settings,setter,NO);
            ((void(*)(id,SEL,id,id,id))objc_msgSend)(_scene,
                NSSelectorFromString(@"updateSettings:withTransitionContext:completion:"),settings,nil,[acknowledged copy]);
        }
    } @catch(NSException *exception) {
        MWLog(@"native_handoff.transition_failed",@{@"scene":self.sceneIdentifier,@"route":@(route),@"exception":exception.name ?: @"unknown"});
        [self finishNativeHandoff:MWError(64,@"场景交接失败，已结束小窗；请从主屏幕打开原应用。")]; return;
    }
    [self pollNativeHandoff:generation];
}
- (void)pollNativeHandoff:(uint64_t)generation {
    if(!_nativeCompletion) return;
    MWNativeAction action=MWNativeHandoffObserve(&_nativeHandoff,generation,NSProcessInfo.processInfo.systemUptime);
    if(action==MWNativeAbort) {
        [self finishNativeHandoff:MWError(65,@"场景交接超时，已结束小窗；请从主屏幕打开原应用。")]; return;
    }
    if(action==MWNativeRelease) {
        BOOL released=[self tearDown];
        MWNativeAction result=MWNativeHandoffReleased(&_nativeHandoff,generation,released);
        MWLog(@"native_handoff.released",@{@"bundle":self.bundleIdentifier,@"localReleaseConfirmed":@(released)});
        [self finishNativeHandoff:result==MWNativeOpen ? nil :
            MWError(66,@"小窗未能完全释放，未打开原应用。请导出诊断并重启初春星河。")];
        return;
    }
    if(action!=MWNativeWait) return;
    __weak typeof(self) weakSelf=self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(0.05*NSEC_PER_SEC)),dispatch_get_main_queue(),^{
        [weakSelf pollNativeHandoff:generation];
    });
}
- (void)finishNativeHandoff:(NSError *)error {
    void (^completion)(NSError *)=_nativeCompletion; _nativeCompletion=nil;
    MWLog(@"native_handoff.finished",@{@"bundle":self.bundleIdentifier,@"error":MWErrorFields(error)});
    [self close];
    if(completion) completion(error);
}
- (BOOL)tearDown {
    BOOL released=YES;
    [_backgroundLease invalidate]; _backgroundLease=nil; _keepAliveRequested=NO;
    [MWKeyboardFocus.shared unregisterGuest:self.sceneIdentifier];
    if([MWKeyboardFocus.shared hasPendingCleanup]) released=NO;
    if(_observingInput) {
        @try {
            ((void(*)(id,SEL,id))objc_msgSend)(_scene,NSSelectorFromString(@"removeObserver:"),self);
        } @catch(NSException *exception) { MWLog(@"keyboard.guest_observer_cleanup_failed",@{@"scene":self.sceneIdentifier}); }
        _observingInput=NO;
    }
    if(_monitor) { dispatch_source_cancel(_monitor); _monitor=nil; }
    @try { [_transaction setCompletionBlock:nil]; } @catch(NSException *exception) { (void)exception; }
    _transaction=nil;
    @try { [_presenter deactivate]; } @catch(NSException *exception) { released=NO; }
    @try { [_presenter invalidate]; } @catch(NSException *exception) { released=NO; }
    _presenter=nil;
    if(_scene) {
        @try {
            id manager=[PrivClass(FBSceneManager) sharedInstance];
            [manager destroyScene:self.sceneIdentifier withTransitionContext:nil];
            SEL lookup=NSSelectorFromString(@"sceneWithIdentifier:");
            // A returned destroy request alone is not a handoff guarantee.
            if(!MWGuestMethod(manager,lookup,'@',"@") ||
               ((id(*)(id,SEL,id))objc_msgSend)(manager,lookup,self.sceneIdentifier)) released=NO;
        }
        @catch(NSException *exception) {
            released=NO;
            MWLog(@"guest.cleanup_failed",@{@"scene":self.sceneIdentifier,@"reason":exception.reason ?: @"unknown"});
        }
    }
    _scene=nil; _process=nil;
    [_inputEnvironment invalidate]; _inputEnvironment=nil;
    _cleanupFailed=_cleanupFailed || !released;
    return !_cleanupFailed;
}

- (void)dealloc { [self tearDown]; }
@end
