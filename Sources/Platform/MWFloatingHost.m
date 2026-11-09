// SPDX-License-Identifier: Apache-2.0
// Based on the local-root-scene binder approach in FrontBoardAppLauncher.
#import "MWFloatingHost.h"
#import "MWPrivate.h"
#import <notify.h>
#import "MWBackgroundLease.h"
#import "MWSceneUpdateGuard.h"
#import "MWRootWindowAdapter.h"
#import "../Core/MWOverlayStartup.h"
#import "../Diagnostics/MWDiagnostics.h"

@interface FBSSceneSettingsDiff (MWConstruction)
+ (instancetype)diffFromSettings:(id)before toSettings:(id)after;
@end

NSString *const MWFloatingHostWillStopNotification=@"MWFloatingHostWillStop";
NSString *const MWFloatingHostFailedNotification=@"MWFloatingHostFailed";
NSString *const MWFloatingHostVisibilityNotification=@"MWFloatingHostVisibility";
NSString *const MWFloatingHostDidBecomeReadyNotification=@"MWFloatingHostDidBecomeReady";

@implementation MWFloatingHost {
    UIRootWindowScenePresentationBinder *_binder;
    FBScene *_scene;
    int _lockToken;
    BOOL _hasLockToken;
    MWBackgroundLease *_backgroundLease;
    NSString *_guardIdentifier;
    UIMutableApplicationSceneSettings *_guardSettings;
    BOOL _guardActive, _locked;
    MWRootWindowAdapter *_rootAdapter;
    BOOL _stopping;
    BOOL _cleanupFailed;
    id _retainedFailedBinder, _retainedFailedScene;
    MWOverlayStartup _startup;
}
+ (instancetype)shared {
    static MWFloatingHost *host; static dispatch_once_t once;
    dispatch_once(&once,^{host=[self new];});
    return host;
}
- (BOOL)ownsSceneIdentifier:(NSString *)identifier {
    return self.enabled && identifier.length && [identifier isEqual:self.sceneIdentifier];
}
- (BOOL)setEnabled:(BOOL)enabled fromScene:(UIWindowScene *)source error:(NSError **)error {
    NSAssert(NSThread.isMainThread,@"Floating host startup is main-thread owned");
    MWLog(@"overlay.request",@{@"enabled":@(enabled),@"sourceSession":source.session.persistentIdentifier ?: @"none"});
    if(enabled==_enabled) return YES;
    if(_stopping) { if(error) *error=MWError(33,@"浮动工作区正在关闭，请稍后再试。"); return NO; }
    if(enabled && _cleanupFailed) { if(error) *error=MWError(34,@"上次浮窗清理失败，请导出日志并重新启动本应用。"); return NO; }
    if(!enabled) { [self stop]; return YES; }
    Class binderClass=NSClassFromString(@"UIRootWindowScenePresentationBinder");
    if(!source || ![binderClass instancesRespondToSelector:@selector(initWithPriority:displayConfiguration:)]
       || ![binderClass instancesRespondToSelector:@selector(removeScene:)] || ![binderClass instancesRespondToSelector:@selector(invalidate)]
       || ![binderClass instancesRespondToSelector:@selector(_rootView)]) {
        if(error) *error=MWError(30,@"当前系统无法建立浮动工作区。"); return NO;
    }
    @try {
        _rootAdapter=[MWRootWindowAdapter new];
        if(![_rootAdapter prepareWithError:error]) { _rootAdapter=nil; return NO; }
        MWInstallSceneUpdateGuard();
        _backgroundLease=[MWBackgroundLease new];
        NSError *leaseError=nil;
        if(![_backgroundLease acquireWithError:&leaseError]) {
            MWLog(@"overlay.background_failed",MWErrorFields(leaseError));
            if(error) *error=leaseError; _backgroundLease=nil; _rootAdapter=nil; return NO;
        }
        _sceneIdentifier=[@"io.github.uiharuxpro4milkyway.overlay." stringByAppendingString:NSUUID.UUID.UUIDString];
        _binder=[[binderClass alloc] initWithPriority:0 displayConfiguration:source._effectiveSettings.displayConfiguration];
        FBSMutableSceneDefinition *definition=[PrivClass(FBSMutableSceneDefinition) definition];
        definition.identity=[PrivClass(FBSSceneIdentity) identityForIdentifier:_sceneIdentifier];
        definition.clientIdentity=[PrivClass(FBSSceneClientIdentity) localIdentity];
        definition.specification=[PrivClass(UIApplicationSceneSpecification) specification];
        FBSMutableSceneParameters *parameters=[PrivClass(FBSMutableSceneParameters) parametersForSpecification:definition.specification];
        UIMutableApplicationSceneSettings *settings=[source._effectiveSettings mutableCopy];
        settings.persistenceIdentifier=_sceneIdentifier;
        settings.deactivationReasons=0; settings.foreground=YES; settings.interruptionPolicy=0;
        @synchronized(self) { _guardIdentifier=[_sceneIdentifier copy]; _guardSettings=[settings copy]; _guardActive=YES; }
        parameters.settings=settings; parameters.clientSettings=source._effectiveUIClientSettings;
        uint64_t generation=MWOverlayStartupBegin(&_startup,NSProcessInfo.processInfo.systemUptime,2.0);
        _enabled=YES;
        _scene=[[PrivClass(FBSceneManager) sharedInstance] createSceneWithDefinition:definition initialParameters:parameters];
        if(!_scene || !_binder) @throw [NSException exceptionWithName:@"MWFloatingScene" reason:@"未返回浮动场景" userInfo:nil];
        [_binder addScene:_scene];
        // Permit root inspection only after the binder has been asked to host.
        // A nil root during initialization does not establish incompatibility.
        MWOverlayStartupSceneAdded(&_startup,generation);
        MWLog(@"overlay.scene_created",@{@"scene":_sceneIdentifier});
        [self observeLock];
        [self attachRootAdapterAttempt:0 generation:generation];
        return YES;
    } @catch(NSException *exception) {
        MWLog(@"overlay.exception",@{@"reason":exception.reason ?: @"unknown"});
        [self stop];
        if(error) *error=MWError(32,[NSString stringWithFormat:@"开启浮窗失败：%@",exception.reason]);
        return NO;
    }
}
- (void)attachRootAdapterAttempt:(NSUInteger)attempt generation:(uint64_t)generation {
    if(!_enabled || !MWOverlayStartupCanProbe(&_startup,generation) || !_binder || !_rootAdapter) return;
    NSError *rootError=nil;
    id root=nil;
    MWRootAttachmentResult result=MWRootAttachmentUnsupported;
    @try {
        root=[_binder _rootView];
        result=[_rootAdapter attachToRootView:root error:&rootError];
    } @catch(NSException *exception) {
        rootError=MWError(52,[NSString stringWithFormat:@"读取浮窗根视图失败：%@",exception.reason ?: @"未知异常"]);
    }
    MWOverlayRootResult observation=result==MWRootAttachmentReady ? MWOverlayRootReady :
        (result==MWRootAttachmentPending ? MWOverlayRootPending : MWOverlayRootRejected);
    MWOverlayStartupAction action=MWOverlayStartupObserve(&_startup,generation,NSProcessInfo.processInfo.systemUptime,observation);
    MWTrace(@"overlay.root_probe",@{@"attempt":@(attempt),@"generation":@(generation),@"result":@(result),
        @"viewClass":root ? NSStringFromClass([root class]) : @"none",@"windowConnected":@(_startup.windowConnected)});
    if(action==MWOverlayStartupComplete) {
        UIWindow *window=_floatingWindow;
        if(!window) { [self stop]; [[NSNotificationCenter defaultCenter] postNotificationName:MWFloatingHostFailedNotification object:MWError(31,@"浮动窗口已断开，已返回应用内工作台。")]; return; }
        _rootAdapter.overlayWindow=window;
        MWLog(@"overlay.root_ready",@{@"attempt":@(attempt),@"viewClass":root ? NSStringFromClass([root class]) : @"none",@"generation":@(generation)});
        [[NSNotificationCenter defaultCenter] postNotificationName:MWFloatingHostDidBecomeReadyNotification object:window];
        if(!self.ready || _startup.generation!=generation || _floatingWindow!=window) return;
        // The workspace is transferred exactly once, after both native objects
        // exist. Lock state is applied again before enabling user interaction.
        window.userInteractionEnabled=YES;
        window.hidden=_locked;
        if(!_locked) [window makeKeyAndVisible];
        [self applyLocked:_locked];
        return;
    }
    if(action==MWOverlayStartupWait) {
        __weak typeof(self) weakSelf=self;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(0.05*NSEC_PER_SEC)),dispatch_get_main_queue(),^{
            [weakSelf attachRootAdapterAttempt:attempt+1 generation:generation];
        });
        return;
    }
    if(action==MWOverlayStartupIgnore) return;
    MWLog(@"overlay.root_rejected",@{@"attempt":@(attempt),@"error":MWErrorFields(rootError),@"viewClass":root ? NSStringFromClass([root class]) : @"none"});
    NSError *error=rootError ?: MWError(53,@"浮窗场景已创建，但根视图或窗口在 2 秒内未连接，已返回应用内工作台。请导出诊断日志。");
    [self stop];
    [[NSNotificationCenter defaultCenter] postNotificationName:MWFloatingHostFailedNotification object:error];
}
- (void)observeLock {
    __weak typeof(self) weakSelf=self;
    uint32_t result=notify_register_dispatch("com.apple.springboard.lockstate",&_lockToken,dispatch_get_main_queue(),^(int token){
        uint64_t locked=0;
        if(notify_get_state(token,&locked)==NOTIFY_STATUS_OK)
            [weakSelf applyLocked:(locked!=0)];
    });
    _hasLockToken=(result==NOTIFY_STATUS_OK);
    MWLog(@"overlay.lock_observer",@{@"registered":@(_hasLockToken),@"result":@(result)});
    if(_hasLockToken) {
        uint64_t locked=0;
        if(notify_get_state(_lockToken,&locked)==NOTIFY_STATUS_OK) [self applyLocked:(locked!=0)];
    }
}
- (void)setFloatingWindow:(UIWindow *)floatingWindow {
    if(![self ownsSceneIdentifier:floatingWindow.windowScene.session.persistentIdentifier]) {
        floatingWindow.hidden=YES;
        MWLog(@"overlay.window_stale",@{@"session":floatingWindow.windowScene.session.persistentIdentifier ?: @"none"}); return;
    }
    _floatingWindow=floatingWindow;
    _rootAdapter.overlayWindow=floatingWindow;
    MWOverlayStartupWindowConnected(&_startup,_startup.generation);
    MWLog(@"overlay.window_attached",@{@"session":floatingWindow.windowScene.session.persistentIdentifier ?: @"none",@"backgroundValid":@(self.backgroundExecutionValid)});
    if(_hasLockToken) {
        uint64_t locked=0;
        if(notify_get_state(_lockToken,&locked)==NOTIFY_STATUS_OK) [self applyLocked:(locked!=0)];
    }
}
- (void)applyLocked:(BOOL)locked {
    _locked=locked;
    @synchronized(self) {
        // The client may have accepted a background/lock diff while protection
        // was inactive. Refresh the baseline before normalizing the next diff.
        if(!locked && self.floatingWindow.windowScene) {
            @try { _guardSettings=[self.floatingWindow.windowScene._effectiveSettings mutableCopy]; }
            @catch(NSException *exception) { MWLog(@"guard.snapshot_failed",@{@"reason":exception.reason ?: @"unknown"}); }
        }
        _guardActive=_enabled && !locked;
    }
    MWLog(@"overlay.lock",@{@"locked":@(locked)});
    self.floatingWindow.hidden=locked;
    if(!self.ready) return;
    if(self.floatingWindow) [[NSNotificationCenter defaultCenter] postNotificationName:MWFloatingHostVisibilityNotification object:self.floatingWindow userInfo:@{@"visible":@(!locked)}];
    if(!locked) [self refreshAfterBackgroundTransition];
}
- (void)sceneDisconnected:(NSString *)identifier {
    MWLog(@"overlay.disconnected",@{@"scene":identifier ?: @"none",@"owned":@([self ownsSceneIdentifier:identifier])});
    if([self ownsSceneIdentifier:identifier]) [self stop];
}
- (void)stop {
    if(_stopping) return;
    _stopping=YES;
    MWOverlayStartupCancel(&_startup);
    FBScene *scene=_scene;
    UIRootWindowScenePresentationBinder *binder=_binder;
    NSString *identifier=[_sceneIdentifier copy];
    MWRootWindowAdapter *rootAdapter=_rootAdapter;
    UIWindow *overlay=_floatingWindow;
    MWLog(@"overlay.stopping",@{@"scene":identifier ?: @"none"});
    _enabled=NO;
    @synchronized(self) { _guardActive=NO; _guardIdentifier=nil; _guardSettings=nil; }
    overlay.hidden=YES;
    [[NSNotificationCenter defaultCenter] postNotificationName:MWFloatingHostWillStopNotification object:self];
    if(_hasLockToken) { notify_cancel(_lockToken); _hasLockToken=NO; }
    _floatingWindow=nil;
    // Invalidate automatic presenters while their scene and binder still live.
    // Destroying the FBScene or dropping the binder first triggers the observed
    // UIAutomaticScenePresenter deallocation assertion on iOS 16.2.
    if(binder && scene) {
        @try { [binder removeScene:scene]; MWLog(@"overlay.binder_scene_removed",@{@"scene":identifier ?: @"none"}); }
        @catch(NSException *exception) { MWLog(@"overlay.binder_remove_failed",@{@"reason":exception.reason ?: @"unknown"}); }
    }
    BOOL binderInvalidated=(binder==nil);
    if(binder) {
        @try { [binder invalidate]; binderInvalidated=YES; MWLog(@"overlay.binder_invalidated",@{}); }
        @catch(NSException *exception) {
            _cleanupFailed=YES; _retainedFailedBinder=binder; _retainedFailedScene=scene;
            MWLog(@"overlay.binder_invalidate_failed",@{@"reason":exception.reason ?: @"unknown",@"resourcesRetained":@YES});
        }
    }
    if(binderInvalidated && scene && identifier) {
        @try { [[PrivClass(FBSceneManager) sharedInstance] destroyScene:identifier withTransitionContext:nil]; MWLog(@"overlay.scene_destroyed",@{@"scene":identifier}); }
        @catch(NSException *exception) { MWLog(@"overlay.scene_destroy_failed",@{@"reason":exception.reason ?: @"unknown"}); }
    }
    [rootAdapter detach]; _rootAdapter=nil;
    _scene=nil; _binder=nil; _sceneIdentifier=nil; _locked=NO;
    [_backgroundLease invalidate]; _backgroundLease=nil;
    _stopping=NO;
    if(!binderInvalidated) [[NSNotificationCenter defaultCenter] postNotificationName:MWFloatingHostFailedNotification object:MWError(34,@"浮窗已隐藏，但系统呈现对象清理失败。请导出日志后重新启动本应用。")];
    [MWDiagnostics.shared flush];
}
- (BOOL)backgroundExecutionValid { return _backgroundLease.valid; }
- (BOOL)isReady { return _enabled && _startup.phase==MWOverlayStartupReady; }
- (id)protectedDiff:(id)diff forIdentifier:(NSString *)identifier {
    @synchronized(self) {
        if(![_guardIdentifier isEqual:identifier] || !diff) return diff;
        @try {
            Class diffClass=[diff class];
            if(![diff respondsToSelector:@selector(settingsByApplyingToMutableCopyOfSettings:)] || ![diffClass respondsToSelector:@selector(diffFromSettings:toSettings:)]) {
                MWLog(@"guard.passthrough",@{@"reason":@"unsupported diff API",@"class":NSStringFromClass(diffClass)}); return diff;
            }
            UIMutableApplicationSceneSettings *after=[diff settingsByApplyingToMutableCopyOfSettings:_guardSettings];
            if(!_guardActive) {
                _guardSettings=[after copy];
                MWTrace(@"guard.observed_unprotected",@{@"scene":identifier});
                return diff;
            }
            if(![after respondsToSelector:@selector(setForeground:)] || ![after respondsToSelector:@selector(setDeactivationReasons:)]) return diff;
            BOOL wasForeground=[after isForeground];
            after.foreground=YES; after.deactivationReasons=0;
            id protected=[diffClass diffFromSettings:_guardSettings toSettings:after];
            if(!protected) return diff;
            _guardSettings=[after copy];
            MWTrace(@"guard.normalized",@{@"scene":identifier,@"incomingForeground":@(wasForeground)});
            return protected;
        } @catch(NSException *exception) {
            MWLog(@"guard.passthrough",@{@"reason":exception.reason ?: @"exception"}); return diff;
        }
    }
}
- (void)refreshAfterBackgroundTransition {
    if(!self.ready || _locked) return;
    MWLog(@"overlay.host_background",@{@"backgroundValid":@(self.backgroundExecutionValid),@"attached":@(_floatingWindow!=nil)});
    @try {
        [_scene updateSettingsWithBlock:^(UIMutableApplicationSceneSettings *settings) {
            settings.foreground=YES; settings.deactivationReasons=0;
        }];
        _floatingWindow.hidden=NO;
    } @catch(NSException *exception) { MWLog(@"overlay.refresh_failed",@{@"reason":exception.reason ?: @"unknown"}); }
    [MWDiagnostics.shared flush];
}
@end

