// SPDX-License-Identifier: Apache-2.0
// Based on the local-root-scene binder approach in FrontBoardAppLauncher.
#import "MWFloatingHost.h"
#import "MWPrivate.h"
#import <notify.h>

NSString *const MWFloatingHostWillStopNotification=@"MWFloatingHostWillStop";
NSString *const MWFloatingHostFailedNotification=@"MWFloatingHostFailed";
NSString *const MWFloatingHostVisibilityNotification=@"MWFloatingHostVisibility";

@implementation MWFloatingHost {
    UIRootWindowScenePresentationBinder *_binder;
    FBScene *_scene;
    int _lockToken;
    BOOL _hasLockToken;
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
    if(enabled==_enabled) return YES;
    if(!enabled) { [self stop]; return YES; }
    Class binderClass=NSClassFromString(@"UIRootWindowScenePresentationBinder");
    if(!source || ![binderClass instancesRespondToSelector:@selector(initWithPriority:displayConfiguration:)]) {
        if(error) *error=MWError(30,@"当前系统无法建立浮动工作区。"); return NO;
    }
    @try {
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
        parameters.settings=settings; parameters.clientSettings=source._effectiveUIClientSettings;
        _enabled=YES;
        _scene=[[PrivClass(FBSceneManager) sharedInstance] createSceneWithDefinition:definition initialParameters:parameters];
        if(!_scene || !_binder) @throw [NSException exceptionWithName:@"MWFloatingScene" reason:@"未返回浮动场景" userInfo:nil];
        [_binder addScene:_scene];
        [self observeLock];
        NSString *identifier=[_sceneIdentifier copy];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,5*NSEC_PER_SEC),dispatch_get_main_queue(),^{
            if([self ownsSceneIdentifier:identifier] && !self.floatingWindow) {
                [self stop];
                [[NSNotificationCenter defaultCenter] postNotificationName:MWFloatingHostFailedNotification object:MWError(31,@"系统未连接浮动工作区，已返回应用内模式。")];
            }
        });
        return YES;
    } @catch(NSException *exception) {
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
    if(_hasLockToken) {
        uint64_t locked=0;
        if(notify_get_state(_lockToken,&locked)==NOTIFY_STATUS_OK) [self applyLocked:(locked!=0)];
    }
}
- (void)applyLocked:(BOOL)locked {
    self.floatingWindow.hidden=locked;
    if(self.floatingWindow) [[NSNotificationCenter defaultCenter] postNotificationName:MWFloatingHostVisibilityNotification object:self.floatingWindow userInfo:@{@"visible":@(!locked)}];
}
- (void)sceneDisconnected:(NSString *)identifier {
    if([self ownsSceneIdentifier:identifier]) [self stop];
}
- (void)stop {
    _enabled=NO;
    [[NSNotificationCenter defaultCenter] postNotificationName:MWFloatingHostWillStopNotification object:self];
    if(_hasLockToken) { notify_cancel(_lockToken); _hasLockToken=NO; }
    self.floatingWindow.hidden=YES; _floatingWindow=nil;
    if(_scene && _sceneIdentifier) {
        @try { [[PrivClass(FBSceneManager) sharedInstance] destroyScene:_sceneIdentifier withTransitionContext:nil]; }
        @catch(NSException *exception) { NSLog(@"Floating scene cleanup: %@",exception.reason); }
    }
    _scene=nil; _binder=nil; _sceneIdentifier=nil;
}
@end

