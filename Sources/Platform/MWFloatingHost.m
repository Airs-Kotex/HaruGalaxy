// SPDX-License-Identifier: Apache-2.0
// Based on the local-root-scene binder approach in FrontBoardAppLauncher.
#import "MWFloatingHost.h"
#import "MWPrivate.h"
#import <notify.h>
#import "MWBackgroundLease.h"
#import "MWSceneUpdateGuard.h"
#import "../Diagnostics/MWDiagnostics.h"

@interface FBSSceneSettingsDiff (MWConstruction)
+ (instancetype)diffFromSettings:(id)before toSettings:(id)after;
@end

NSString *const MWFloatingHostWillStopNotification=@"MWFloatingHostWillStop";
NSString *const MWFloatingHostFailedNotification=@"MWFloatingHostFailed";
NSString *const MWFloatingHostVisibilityNotification=@"MWFloatingHostVisibility";

@implementation MWFloatingHost {
    UIRootWindowScenePresentationBinder *_binder;
    FBScene *_scene;
    int _lockToken;
    BOOL _hasLockToken;
    MWBackgroundLease *_backgroundLease;
    NSString *_guardIdentifier;
    UIMutableApplicationSceneSettings *_guardSettings;
    BOOL _guardActive, _locked;
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
    MWLog(@"overlay.request",@{@"enabled":@(enabled),@"sourceSession":source.session.persistentIdentifier ?: @"none"});
    if(enabled==_enabled) return YES;
    if(!enabled) { [self stop]; return YES; }
    Class binderClass=NSClassFromString(@"UIRootWindowScenePresentationBinder");
    if(!source || ![binderClass instancesRespondToSelector:@selector(initWithPriority:displayConfiguration:)]) {
        if(error) *error=MWError(30,@"当前系统无法建立浮动工作区。"); return NO;
    }
    @try {
        MWInstallSceneUpdateGuard();
        _backgroundLease=[MWBackgroundLease new];
        NSError *leaseError=nil;
        if(![_backgroundLease acquireWithError:&leaseError]) {
            MWLog(@"overlay.background_failed",MWErrorFields(leaseError));
            if(error) *error=leaseError; _backgroundLease=nil; return NO;
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
        _enabled=YES;
        _scene=[[PrivClass(FBSceneManager) sharedInstance] createSceneWithDefinition:definition initialParameters:parameters];
        if(!_scene || !_binder) @throw [NSException exceptionWithName:@"MWFloatingScene" reason:@"未返回浮动场景" userInfo:nil];
        [_binder addScene:_scene];
        MWLog(@"overlay.scene_created",@{@"scene":_sceneIdentifier});
        [self observeLock];
        NSString *identifier=[_sceneIdentifier copy];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,5*NSEC_PER_SEC),dispatch_get_main_queue(),^{
            if([self ownsSceneIdentifier:identifier] && !self.floatingWindow) {
                MWLog(@"overlay.connect_timeout",@{@"scene":identifier});
                [self stop];
                [[NSNotificationCenter defaultCenter] postNotificationName:MWFloatingHostFailedNotification object:MWError(31,@"系统未连接浮动工作区，已返回应用内模式。")];
            }
        });
        return YES;
    } @catch(NSException *exception) {
        MWLog(@"overlay.exception",@{@"reason":exception.reason ?: @"unknown"});
        [self stop];
        if(error) *error=MWError(32,[NSString stringWithFormat:@"开启浮窗失败：%@",exception.reason]);
        return NO;
    }
}
- (void)observeLock {
    __weak typeof(self) weakSelf=self;
    uint32_t result=notify_register_dispatch("com.apple.springboard.lockstate",&_lockToken,dispatch_get_main_queue(),^(int token){
        uint64_t locked=0;
        if(notify_get_state(token,&locked)==NOTIFY_STATUS_OK)
            [weakSelf applyLocked:(locked!=0)];
    });
    _hasLockToken=(result==NOTIFY_STATUS_OK);
}
- (void)setFloatingWindow:(UIWindow *)floatingWindow {
    _floatingWindow=floatingWindow;
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
    if(self.floatingWindow) [[NSNotificationCenter defaultCenter] postNotificationName:MWFloatingHostVisibilityNotification object:self.floatingWindow userInfo:@{@"visible":@(!locked)}];
    if(!locked) [self refreshAfterBackgroundTransition];
}
- (void)sceneDisconnected:(NSString *)identifier {
    MWLog(@"overlay.disconnected",@{@"scene":identifier ?: @"none",@"owned":@([self ownsSceneIdentifier:identifier])});
    if([self ownsSceneIdentifier:identifier]) [self stop];
}
- (void)stop {
    MWLog(@"overlay.stopping",@{@"scene":_sceneIdentifier ?: @"none"});
    _enabled=NO;
    @synchronized(self) { _guardActive=NO; _guardIdentifier=nil; _guardSettings=nil; }
    [_backgroundLease invalidate]; _backgroundLease=nil;
    [[NSNotificationCenter defaultCenter] postNotificationName:MWFloatingHostWillStopNotification object:self];
    if(_hasLockToken) { notify_cancel(_lockToken); _hasLockToken=NO; }
    self.floatingWindow.hidden=YES; _floatingWindow=nil;
    if(_scene && _sceneIdentifier) {
        @try { [[PrivClass(FBSceneManager) sharedInstance] destroyScene:_sceneIdentifier withTransitionContext:nil]; }
        @catch(NSException *exception) { NSLog(@"Floating scene cleanup: %@",exception.reason); }
    }
    _scene=nil; _binder=nil; _sceneIdentifier=nil;
    [MWDiagnostics.shared flush];
}
- (BOOL)backgroundExecutionValid { return _backgroundLease.valid; }
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
    if(!_enabled || _locked) return;
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

