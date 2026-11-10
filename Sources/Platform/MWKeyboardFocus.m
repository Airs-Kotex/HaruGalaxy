// SPDX-License-Identifier: Apache-2.0
// Selectors: MTACS/iOS-17-Runtime-Headers, UIKitCore. Calls are capability/ABI
// checked on the running OS. Real focus grants remain system controlled.
#import "MWKeyboardFocus.h"
#import "../Core/MWKeyboardFocusState.h"
#import "../Core/MWRuntimeTypes.h"
#import "../Diagnostics/MWDiagnostics.h"
#import <objc/runtime.h>
#import <objc/message.h>
#import <unistd.h>
#include <string.h>

static BOOL MWKeyboardMethod(id object,SEL selector,char result,const char *arguments) {
    if(!object || ![object respondsToSelector:selector]) return NO;
    Method method=class_getInstanceMethod(object_getClass(object),selector);
    if(!method || method_getNumberOfArguments(method)!=strlen(arguments)+2) return NO;
    char type[128]={0}; method_getReturnType(method,type,sizeof(type));
    if(!MWObjCTypeMatches(type,result)) return NO;
    for(unsigned i=0;i<strlen(arguments);i++) {
        method_getArgumentType(method,i+2,type,sizeof(type));
        if(!MWObjCTypeMatches(type,arguments[i])) return NO;
    }
    return YES;
}
static id MWKeyboardObject(id object,NSString *name) {
    SEL selector=NSSelectorFromString(name);
    if(!MWKeyboardMethod(object,selector,'@',"")) return nil;
    return ((id(*)(id,SEL))objc_msgSend)(object,selector);
}
static id MWKeyboardBool(id object,NSString *name) {
    SEL selector=NSSelectorFromString(name);
    if(!MWKeyboardMethod(object,selector,'B',"") && !MWKeyboardMethod(object,selector,'c',"")) return @"unavailable";
    return @(((BOOL(*)(id,SEL))objc_msgSend)(object,selector));
}

@interface MWKeyboardGuest : NSObject
@property(nonatomic) pid_t pid;
@property(nonatomic) uint64_t owner;
@property(nonatomic,strong) id sceneToken;
@end
@implementation MWKeyboardGuest
@end

@implementation MWKeyboardFocus {
    NSMutableDictionary<NSString *,MWKeyboardGuest *> *_guests;
    MWKeyboardFocusState _state;
    uint64_t _nextOwner;
    id _manager, _boundClient;
    id _preparedClient;
    UIWindowScene *_preparedScene;
    UIWindow *_preparedKeyboardWindow;
    BOOL _preparationNeedsCleanup;
    pid_t _boundPID;
    NSString *_boundCaller;
    BOOL _bindingNeedsCleanup;
    __weak UIWindow *_window;
    CFTimeInterval _lastRequest;
}
+ (instancetype)shared {
    static MWKeyboardFocus *focus; static dispatch_once_t once;
    dispatch_once(&once,^{focus=[self new];}); return focus;
}
- (instancetype)init {
    if((self=[super init])) {
        _guests=[NSMutableDictionary dictionary];
        NSNotificationCenter *center=NSNotificationCenter.defaultCenter;
        [center addObserver:self selector:@selector(keyboardEvent:) name:UIKeyboardDidShowNotification object:nil];
        [center addObserver:self selector:@selector(keyboardEvent:) name:UIKeyboardDidHideNotification object:nil];
    }
    return self;
}
- (id)manager {
    if(_manager) return _manager;
    @try {
        id candidate=MWKeyboardObject(NSClassFromString(@"UIKeyboardArbiterManager"),@"sharedArbiterManager");
        SEL choose=NSSelectorFromString(@"userSelectedProcessIdentifier:withSceneIdentity:onCompletion:");
        if(!MWKeyboardMethod(candidate,choose,'v',"i@@"))
            candidate=MWKeyboardObject(NSClassFromString(@"_UIRemoteKeyboards"),@"sharedRemoteKeyboards");
        if(MWKeyboardMethod(candidate,choose,'v',"i@@")) _manager=candidate;
    } @catch(NSException *exception) { MWLog(@"keyboard.capability_exception",@{@"reason":exception.reason ?: @"unknown"}); }
    if(!_manager) MWLog(@"keyboard.focus_unavailable",@{@"reason":@"selector or ABI unsupported"});
    return _manager;
}
- (id)client {
    id client=MWKeyboardObject(NSClassFromString(@"UIKeyboardArbiterManager"),@"arbiterClient");
    return client ?: MWKeyboardObject(NSClassFromString(@"_UIKeyboardArbiterClient"),@"automaticSharedArbiterClient");
}
- (id)tokenForScene:(id)scene {
    id token=MWKeyboardObject(scene,@"identityToken");
    Class cls=NSClassFromString(@"FBSSceneIdentityToken");
    return cls && [token isKindOfClass:cls] ? token : nil;
}
- (void)registerGuest:(NSString *)identifier processIdentifier:(pid_t)pid scene:(id)scene {
    NSAssert(NSThread.isMainThread,@"Keyboard ownership is main-thread only");
    if(!identifier.length || pid<=0 || !scene) return;
    [self unregisterGuest:identifier];
    @try {
        id token=[self tokenForScene:scene];
        NSString *actual=MWKeyboardObject(token,@"identifier");
        if(!token || ![actual isKindOfClass:NSString.class] || ![actual isEqual:identifier]) {
            MWLog(@"keyboard.guest_unavailable",@{@"scene":identifier,@"reason":@"scene identity token mismatch"}); return;
        }
        MWKeyboardGuest *guest=[MWKeyboardGuest new]; guest.pid=pid; guest.owner=++_nextOwner; guest.sceneToken=token;
        _guests[identifier]=guest;
        MWLog(@"keyboard.guest_registered",@{@"scene":identifier,@"pid":@(pid)});
    } @catch(NSException *exception) { MWLog(@"keyboard.guest_unavailable",@{@"scene":identifier,@"reason":exception.reason ?: @"exception"}); }
}
- (BOOL)clearHostedBinding {
    if(!_boundCaller) return YES;
    id client=_boundClient; NSString *caller=_boundCaller; pid_t pid=_boundPID;
    @try {
        SEL remove=NSSelectorFromString(@"removeWindowHostingPID:callerID:");
        if(!MWKeyboardMethod(client,remove,'v',"i@")) {
            _bindingNeedsCleanup=YES;
            MWLog(@"keyboard.hosting_cleanup_failed",@{@"reason":@"removal API unavailable",@"pid":@(pid),@"retained":@YES});
            return NO;
        }
        ((void(*)(id,SEL,int,id))objc_msgSend)(client,remove,pid,caller);
        _boundClient=nil; _boundCaller=nil; _boundPID=0; _bindingNeedsCleanup=NO;
        MWTrace(@"keyboard.hosting_removed",@{@"pid":@(pid)});
        return YES;
    } @catch(NSException *exception) {
        _bindingNeedsCleanup=YES;
        MWLog(@"keyboard.hosting_cleanup_failed",@{@"reason":exception.reason ?: @"unknown",@"pid":@(pid),@"retained":@YES});
        return NO;
    }
}
- (BOOL)clearHostedPresentation {
    if(!_preparedClient) return YES;
    @try {
        SEL finish=NSSelectorFromString(@"finishWithHostedWindow");
        if(!MWKeyboardMethod(_preparedClient,finish,'v',"")) {
            _preparationNeedsCleanup=YES;
            MWLog(@"keyboard.presentation_cleanup_failed",@{@"reason":@"finish API unavailable",@"retained":@YES});
            return NO;
        }
        ((void(*)(id,SEL))objc_msgSend)(_preparedClient,finish);
        _preparedClient=nil; _preparedScene=nil; _preparedKeyboardWindow=nil; _preparationNeedsCleanup=NO;
        MWLog(@"keyboard.presentation_finished",@{});
        return YES;
    } @catch(NSException *exception) {
        _preparationNeedsCleanup=YES;
        MWLog(@"keyboard.presentation_cleanup_failed",@{@"reason":exception.reason ?: @"unknown",@"retained":@YES});
        return NO;
    }
}
- (BOOL)clearInputHosting {
    // Keep the presentation alive if its PID binding could not be removed.
    if(![self clearHostedBinding]) return NO;
    return [self clearHostedPresentation];
}
- (BOOL)prepareHostedPresentation:(id)client scene:(UIWindowScene *)scene {
    if(_preparedClient==client && _preparedScene==scene && !_preparationNeedsCleanup) return YES;
    if(![self clearHostedPresentation]) return NO;
    SEL prepare=NSSelectorFromString(@"prepareForHostedWindowWithScene:");
    SEL finish=NSSelectorFromString(@"finishWithHostedWindow");
    if(!scene || !MWKeyboardMethod(client,prepare,'@',"@") || !MWKeyboardMethod(client,finish,'v',"")) {
        MWLog(@"keyboard.presentation_unavailable",@{@"reason":@"paired hosting API unavailable"});
        return YES; // Preserve the existing focus-only path on other systems.
    }
    _preparedClient=client; _preparedScene=scene; _preparationNeedsCleanup=YES;
    id window=((id(*)(id,SEL,id))objc_msgSend)(client,prepare,scene);
    _preparationNeedsCleanup=NO;
    if([window isKindOfClass:UIWindow.class]) _preparedKeyboardWindow=window;
    MWLog(@"keyboard.presentation_prepared",@{@"windowReturned":@(window!=nil),
        @"windowClass":window ? NSStringFromClass([window class]) : @"none",
        @"sceneState":@(scene.activationState)});
    return YES;
}
- (BOOL)bindGuest:(MWKeyboardGuest *)guest identifier:(NSString *)identifier window:(UIWindow *)window {
    NSString *caller=guest ? [@"harugalaxy.keyboard." stringByAppendingString:identifier] : nil;
    if(guest && !_bindingNeedsCleanup && !_preparationNeedsCleanup && _boundPID==guest.pid &&
       [_boundCaller isEqual:caller] && (!_preparedScene || _preparedScene==window.windowScene)) return YES;
    if(![self clearHostedBinding]) return NO;
    if(!guest) return [self clearHostedPresentation];
    id client=[self client];
    if(![self prepareHostedPresentation:client scene:window.windowScene]) return NO;
    SEL add=NSSelectorFromString(@"addWindowHostingPID:callerID:"),remove=NSSelectorFromString(@"removeWindowHostingPID:callerID:");
    if(!MWKeyboardMethod(client,add,'v',"i@") || !MWKeyboardMethod(client,remove,'v',"i@")) {
        MWTrace(@"keyboard.hosting_unavailable",@{@"scene":identifier}); return YES;
    }
    _boundClient=client; _boundCaller=caller; _boundPID=guest.pid; _bindingNeedsCleanup=YES;
    ((void(*)(id,SEL,int,id))objc_msgSend)(client,add,guest.pid,caller);
    _bindingNeedsCleanup=NO;
    MWTrace(@"keyboard.hosting_added",@{@"scene":identifier,@"pid":@(guest.pid)});
    return YES;
}
- (void)selectPID:(pid_t)pid token:(id)token owner:(uint64_t)owner window:(UIWindow *)window reason:(NSString *)reason guest:(MWKeyboardGuest *)guest identifier:(NSString *)identifier {
    if(_state.suspended || !window || window.hidden || !window.userInteractionEnabled || !token) return;
    // Repeated activation notifications in one frame need not renegotiate.
    CFTimeInterval now=CACurrentMediaTime();
    if(_state.selected && _state.owner==owner && _window==window && now-_lastRequest<0.15) return;
    @try {
        id manager=[self manager]; if(!manager) return;
        [window makeKeyWindow];
        if(![self bindGuest:guest identifier:identifier window:window]) {
            MWLog(@"keyboard.focus_blocked",@{@"reason":@"previous hosting cleanup pending",@"owner":@(owner)});
            return;
        }
        uint64_t generation=MWKeyboardFocusSelect(&_state,owner); if(!generation) return;
        _window=window; _lastRequest=now;
        __weak typeof(self) weakSelf=self;
        // Callback is only a completion notification. We neither read nor infer
        // a grant result from undocumented completion arguments.
        dispatch_block_t completion=^{
            dispatch_async(dispatch_get_main_queue(),^{
                MWKeyboardFocus *focus=weakSelf;
                if(focus && MWKeyboardFocusCurrent(&focus->_state,owner,generation))
                    MWTrace(@"keyboard.focus_completed",@{@"owner":@(owner),@"generation":@(generation),@"state":[focus snapshot]});
            });
        };
        ((void(*)(id,SEL,int,id,id))objc_msgSend)(manager,
            NSSelectorFromString(@"userSelectedProcessIdentifier:withSceneIdentity:onCompletion:"),pid,token,[completion copy]);
        MWLog(@"keyboard.focus_requested",@{@"pid":@(pid),@"owner":@(owner),@"reason":reason,@"generation":@(generation),
            @"windowClass":NSStringFromClass(window.class),@"sceneState":@(window.windowScene.activationState),@"state":[self snapshot]});
        if(guest) {
            for(NSNumber *delay in @[@0.35,@1.0]) {
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(delay.doubleValue*NSEC_PER_SEC)),dispatch_get_main_queue(),^{
                    MWKeyboardFocus *focus=weakSelf;
                    if(focus && MWKeyboardFocusCurrent(&focus->_state,owner,generation))
                        MWLog(@"keyboard.focus_observed",@{@"pid":@(pid),@"owner":@(owner),
                            @"after":delay,@"state":[focus snapshot]});
                });
            }
        }
    } @catch(NSException *exception) {
        MWKeyboardFocusRelease(&_state,owner); [self clearInputHosting];
        MWLog(@"keyboard.focus_failed",@{@"reason":exception.reason ?: @"unknown",@"pid":@(pid)});
    }
}
- (void)focusGuest:(NSString *)identifier inWindow:(UIWindow *)window {
    NSAssert(NSThread.isMainThread,@"Keyboard ownership is main-thread only");
    MWKeyboardGuest *guest=_guests[identifier];
    if(guest) [self selectPID:guest.pid token:guest.sceneToken owner:guest.owner window:window reason:@"guest_touch" guest:guest identifier:identifier];
}
- (void)refreshGuest:(NSString *)identifier inWindow:(UIWindow *)window {
    NSAssert(NSThread.isMainThread,@"Keyboard ownership is main-thread only");
    MWKeyboardGuest *guest=_guests[identifier];
    // An app may report delayed/autofocused input after the panel or host
    // picker took focus. Observations may refresh, never choose a new owner.
    if(guest && _window==window && MWKeyboardFocusCurrent(&_state,guest.owner,_state.generation))
        [self selectPID:guest.pid token:guest.sceneToken owner:guest.owner window:window reason:@"guest_input_state" guest:guest identifier:identifier];
}
- (void)focusHostWindow:(UIWindow *)window reason:(NSString *)reason {
    NSAssert(NSThread.isMainThread,@"Keyboard ownership is main-thread only");
    if(!window || _state.suspended) return;
    @try {
        id scene=MWKeyboardObject(window.windowScene,@"_FBSScene");
        id token=[self tokenForScene:scene];
        if(!token) { MWLog(@"keyboard.local_unavailable",@{@"reason":@"missing native scene token"}); return; }
        [self selectPID:getpid() token:token owner:0 window:window reason:reason guest:nil identifier:nil];
    } @catch(NSException *exception) { MWLog(@"keyboard.local_unavailable",@{@"reason":exception.reason ?: @"unknown"}); }
}
- (void)releaseGuest:(NSString *)identifier {
    MWKeyboardGuest *guest=_guests[identifier];
    if(guest && MWKeyboardFocusRelease(&_state,guest.owner)) { [self clearInputHosting]; _window=nil; }
}
- (void)unregisterGuest:(NSString *)identifier {
    if(!identifier.length) return;
    [self releaseGuest:identifier]; [_guests removeObjectForKey:identifier];
}
- (void)releaseForWindow:(UIWindow *)window {
    if(_window!=window || !window) return;
    MWKeyboardFocusRelease(&_state,_state.owner); [self clearInputHosting]; _window=nil;
}
- (void)setSuspended:(BOOL)suspended {
    MWKeyboardFocusSuspend(&_state,suspended);
    if(suspended) { [self clearInputHosting]; _window=nil; }
    MWTrace(@"keyboard.suspended",@{@"suspended":@(suspended)});
}
- (NSDictionary *)snapshot {
    @try {
        id client=[self client];
        id remote=MWKeyboardObject(NSClassFromString(@"_UIRemoteKeyboards"),@"sharedRemoteKeyboards");
        id state=MWKeyboardObject(client,@"currentClientState") ?: MWKeyboardObject(remote,@"currentState");
        id source=MWKeyboardObject(state,@"sourceSceneIdentityString");
        return @{@"selected":@(_state.selected),@"owner":@(_state.owner),@"suspended":@(_state.suspended),
            @"client":client ? NSStringFromClass([client class]) : @"unavailable",
            @"allowed":MWKeyboardBool(client,@"allowedToShowKeyboard"),
            @"active":MWKeyboardBool(client,@"keyboardActive"),@"visible":MWKeyboardBool(client,@"keyboardVisible"),
            @"hosted":@(_boundCaller!=nil),@"cleanupPending":@(_bindingNeedsCleanup || _preparationNeedsCleanup),
            @"presentationPrepared":@(_preparedClient!=nil),@"keyboardWindowPresent":@(_preparedKeyboardWindow!=nil),
            @"keyboardWindowHidden":@(_preparedKeyboardWindow.hidden),
            @"sourceScene":[source isKindOfClass:NSString.class] ? source : @"unavailable",
            @"registeredGuests":@(_guests.count)};
    } @catch(NSException *exception) { return @{@"snapshotUnavailable":@YES}; }
}
- (BOOL)hasPendingCleanup { return _bindingNeedsCleanup || _preparationNeedsCleanup; }
- (void)keyboardEvent:(NSNotification *)notification {
    MWLog(@"keyboard.visibility",@{@"notification":notification.name,@"state":[self snapshot]});
}
- (void)dealloc { [[NSNotificationCenter defaultCenter] removeObserver:self]; }
@end
