// SPDX-License-Identifier: Apache-2.0
// Scene lifecycle adapted from FrontBoardAppLauncher; redesigned cancellation,
// identity, cleanup and failure handling. No guest process termination.
#import "MWSceneSession.h"
#import "MWPrivate.h"
#include <signal.h>
#include <errno.h>
#import "../Diagnostics/MWDiagnostics.h"

@implementation MWSceneSession {
    FBApplicationProcessLaunchTransaction *_transaction;
    FBScene *_scene;
    _UIScenePresenter *_presenter;
    RBSProcessHandle *_process;
    dispatch_source_t _monitor;
    void (^_completion)(NSError *);
    BOOL _started, _closed, _visible;
    NSUInteger _generation;
    CGSize _size;
    UIInterfaceOrientation _orientation;
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
    _started=YES; _size=size; _completion=[completion copy];
    MWLog(@"guest.launch_requested",@{@"bundle":self.bundleIdentifier,@"scene":self.sceneIdentifier,@"width":@(size.width),@"height":@(size.height)});
    NSString *issue=MWSceneCapabilityIssue();
    if(issue) { [self fail:MWError(11,issue)]; return; }
    NSUInteger generation=++_generation;
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
        [[PrivClass(FBProcessManager) sharedInstance] registerProcessForAuditToken:_process.auditToken];
        FBSMutableSceneDefinition *definition=[PrivClass(FBSMutableSceneDefinition) definition];
        definition.identity=[PrivClass(FBSSceneIdentity) identityForIdentifier:self.sceneIdentifier];
        definition.clientIdentity=[PrivClass(FBSSceneClientIdentity) identityForProcessIdentity:_process.identity];
        definition.specification=[PrivClass(UIApplicationSceneSpecification) specification];
        FBSMutableSceneParameters *parameters=[PrivClass(FBSMutableSceneParameters) parametersForSpecification:definition.specification];
        UIMutableApplicationSceneSettings *settings=[PrivClass(UIMutableApplicationSceneSettings) new];
        settings.displayConfiguration=UIScreen.mainScreen.displayConfiguration;
        settings.foreground=_visible;
        settings.frame=(CGRect){CGPointZero,_size};
        settings.interfaceOrientation=_orientation;
        settings.level=1;
        settings.canShowAlerts=YES;
        settings.persistenceIdentifier=self.sceneIdentifier;
        settings.peripheryInsets=UIEdgeInsetsZero;
        settings.safeAreaInsetsPortrait=UIEdgeInsetsZero;
        settings.statusBarDisabled=YES;
        parameters.settings=settings;
        UIMutableApplicationSceneClientSettings *client=[PrivClass(UIMutableApplicationSceneClientSettings) new];
        client.interfaceOrientation=_orientation;
        parameters.clientSettings=client;
        _scene=[[PrivClass(FBSceneManager) sharedInstance] createSceneWithDefinition:definition initialParameters:parameters];
        _presenter=[_scene.uiPresentationManager createPresenterWithIdentifier:self.sceneIdentifier];
        if(!_scene || !_presenter) {
            [self fail:MWError(16,@"此应用未提供可显示的场景，可能不支持小窗。")]; return;
        }
        [_presenter activate];
        if(!_presenter.presentationView) { [self fail:MWError(16,@"应用未提供可显示的小窗视图。")]; return; }
        if(!_visible) [_presenter deactivate];
        MWLog(@"guest.presenter_ready",@{@"bundle":self.bundleIdentifier,@"scene":self.sceneIdentifier,@"pid":@(_process.pid),@"note":@"presenter object only; first frame not observed"});
        _transaction=nil;
        void (^completion)(NSError *)=_completion; _completion=nil;
        if(completion) completion(nil);
        if(!_closed) [self startMonitoring];
    } @catch(NSException *exception) {
        [self fail:MWError(17,[NSString stringWithFormat:@"建立小窗失败：%@",exception.reason])];
    }
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
    });
    dispatch_resume(_monitor);
}

- (void)updateSize:(CGSize)size orientation:(UIInterfaceOrientation)orientation {
    if(_closed || !isfinite(size.width) || !isfinite(size.height) || size.width<1 || size.height<1) return;
    _size=size;
    if(orientation!=UIInterfaceOrientationUnknown) _orientation=orientation;
    if(!_scene) return;
    MWTrace(@"guest.logical_geometry",@{@"bundle":self.bundleIdentifier,@"width":@(size.width),@"height":@(size.height),@"orientation":@(orientation)});
    @try {
        UIInterfaceOrientation resolved=_orientation;
        [_scene updateSettingsWithBlock:^(UIMutableApplicationSceneSettings *settings) {
            settings.frame=(CGRect){CGPointZero,size}; settings.interfaceOrientation=resolved;
        }];
    } @catch(NSException *exception) {
        [self fail:MWError(19,[NSString stringWithFormat:@"更新小窗尺寸失败：%@",exception.reason])];
    }
}

- (void)setVisible:(BOOL)visible {
    if(_closed) return;
    _visible=visible;
    MWTrace(@"guest.visibility",@{@"bundle":self.bundleIdentifier,@"visible":@(visible)});
    @try {
        [_scene updateSettingsWithBlock:^(UIMutableApplicationSceneSettings *settings) { settings.foreground=visible; }];
        if(visible) [_presenter activate]; else [_presenter deactivate];
    } @catch(NSException *exception) {
        [self fail:MWError(20,[NSString stringWithFormat:@"更新窗口状态失败：%@",exception.reason])];
    }
}

- (void)fail:(NSError *)error {
    if(_closed) return;
    MWLog(@"guest.failed",@{@"bundle":self.bundleIdentifier,@"scene":self.sceneIdentifier,@"error":MWErrorFields(error)});
    void (^completion)(NSError *)=_completion;
    void (^failure)(NSError *)=self.failureHandler;
    [self close];
    if(completion) completion(error); else if(failure) failure(error);
}

- (void)close {
    if(_closed) return;
    MWLog(@"guest.close",@{@"bundle":self.bundleIdentifier,@"scene":self.sceneIdentifier});
    _closed=YES; ++_generation; _completion=nil; self.failureHandler=nil;
    [self tearDown];
}

- (void)tearDown {
    if(_monitor) { dispatch_source_cancel(_monitor); _monitor=nil; }
    @try { [_transaction setCompletionBlock:nil]; } @catch(NSException *exception) { (void)exception; }
    _transaction=nil;
    @try { [_presenter deactivate]; } @catch(NSException *exception) { (void)exception; }
    @try { [_presenter invalidate]; } @catch(NSException *exception) { (void)exception; }
    _presenter=nil;
    if(_scene) {
        @try { [[PrivClass(FBSceneManager) sharedInstance] destroyScene:self.sceneIdentifier withTransitionContext:nil]; }
        @catch(NSException *exception) { MWLog(@"guest.cleanup_failed",@{@"scene":self.sceneIdentifier,@"reason":exception.reason ?: @"unknown"}); }
    }
    _scene=nil; _process=nil;
}

- (void)dealloc { [self tearDown]; }
@end
