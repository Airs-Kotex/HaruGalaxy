// SPDX-License-Identifier: Apache-2.0
// Based on the documented visibility-graph issue investigated by khanhduytran0
// and HugeBlack. Original implementation: exact owned PID/environment matching.
#import "MWSceneInputEnvironment.h"
#import "../Core/MWSceneInputTarget.h"
#import "../Core/MWRuntimeTypes.h"
#import "../Diagnostics/MWDiagnostics.h"
#import <objc/runtime.h>
#import <objc/message.h>
#import <dlfcn.h>

@interface MWInputEnvironmentEntry : NSObject
@property(nonatomic) pid_t pid;
@property(nonatomic,copy) NSString *original;
@property(nonatomic,copy) NSString *replacement;
@property(nonatomic) BOOL reported;
@end
@implementation MWInputEnvironmentEntry
@end

static NSMutableDictionary<NSString *,MWInputEnvironmentEntry *> *MWInputEnvironments;
static id (*MWOriginalInputTarget)(id,SEL,int,id);
static NSString *(*MWEnvironmentForIdentityString)(NSString *);

static id MWInputTarget(id cls,SEL selector,int pid,id environment) {
    NSString *effective=environment; BOOL report=NO;
    if([environment isKindOfClass:NSString.class]) {
        @synchronized(MWInputEnvironments) {
            for(MWInputEnvironmentEntry *entry in MWInputEnvironments.allValues) {
                if(MWSceneInputTargetMatches(pid,[environment UTF8String],entry.pid,entry.original.UTF8String)) {
                    effective=entry.replacement;
                    report=!entry.reported; entry.reported=YES; break;
                }
            }
        }
    }
    // Leave the visibility propagation mechanism itself intact; only the
    // registered scene's input target environment is separated from its host.
    id target=MWOriginalInputTarget(cls,selector,pid,effective);
    if(report) MWLog(@"keyboard.environment_applied",@{@"pid":@(pid),@"targetReturned":@(target!=nil)});
    return target;
}
static BOOL MWInstallInputEnvironment(void) {
    static BOOL installed=NO; if(installed) return YES;
    Class cls=NSClassFromString(@"RBSTarget");
    SEL selector=NSSelectorFromString(@"targetWithPid:environmentIdentifier:");
    Method method=class_getClassMethod(cls,selector);
    if(!method || method_getNumberOfArguments(method)!=4) return NO;
    char type[64]={0}; method_getReturnType(method,type,sizeof(type));
    if(!MWObjCTypeMatches(type,'@')) return NO;
    method_getArgumentType(method,2,type,sizeof(type)); if(!MWObjCTypeMatches(type,'i')) return NO;
    method_getArgumentType(method,3,type,sizeof(type)); if(!MWObjCTypeMatches(type,'@')) return NO;
    MWEnvironmentForIdentityString=dlsym(RTLD_DEFAULT,"_UISVisibilityEnvironmentForSceneIdentityTokenString");
    if(!MWEnvironmentForIdentityString) {
        void *services=dlopen("/System/Library/PrivateFrameworks/UIKitServices.framework/UIKitServices",RTLD_LAZY|RTLD_GLOBAL);
        if(services) MWEnvironmentForIdentityString=dlsym(services,"_UISVisibilityEnvironmentForSceneIdentityTokenString");
        // Keep this image loaded for the lifetime of the installed interposer.
    }
    if(!MWEnvironmentForIdentityString) return NO;
    MWInputEnvironments=[NSMutableDictionary dictionary];
    MWOriginalInputTarget=(id(*)(id,SEL,int,id))method_getImplementation(method);
    class_replaceMethod(object_getClass(cls),selector,(IMP)MWInputTarget,method_getTypeEncoding(method));
    installed=YES; return YES;
}
static id MWInputObject(id object,NSString *name) {
    SEL selector=NSSelectorFromString(name);
    Method method=class_getInstanceMethod(object_getClass(object),selector);
    if(!object || !method || method_getNumberOfArguments(method)!=2) return nil;
    char type[64]={0}; method_getReturnType(method,type,sizeof(type));
    if(!MWObjCTypeMatches(type,'@')) return nil;
    return ((id(*)(id,SEL))objc_msgSend)(object,selector);
}

@implementation MWSceneInputEnvironment {
    NSString *_key;
}
- (instancetype)initWithScene:(id)scene identifier:(NSString *)identifier processIdentifier:(pid_t)pid {
    if((self=[super init])) {
        NSAssert(NSThread.isMainThread,@"Input environment registration is main-thread owned");
        @try {
            if(!identifier.length || pid<=0 || !MWInstallInputEnvironment()) {
                MWLog(@"keyboard.environment_unavailable",@{@"reason":@"runtime API unavailable"}); return self;
            }
            id token=MWInputObject(scene,@"identityToken");
            Class tokenClass=NSClassFromString(@"FBSSceneIdentityToken");
            if(!tokenClass || ![token isKindOfClass:tokenClass]) return self;
            id actual=MWInputObject(token,@"identifier"),representation=MWInputObject(token,@"stringRepresentation");
            if(![actual isKindOfClass:NSString.class] || ![actual isEqual:identifier] ||
               ![representation isKindOfClass:NSString.class]) return self;
            NSString *environment=MWEnvironmentForIdentityString(representation);
            if(![environment isKindOfClass:NSString.class] || !environment.length) return self;
            _key=NSUUID.UUID.UUIDString;
            MWInputEnvironmentEntry *entry=[MWInputEnvironmentEntry new];
            entry.pid=pid; entry.original=environment;
            entry.replacement=[@"HaruGalaxyInput:" stringByAppendingString:_key];
            @synchronized(MWInputEnvironments) { MWInputEnvironments[_key]=entry; }
            MWLog(@"keyboard.environment_registered",@{@"scene":identifier,@"pid":@(pid)});
        } @catch(NSException *exception) {
            [self invalidate];
            MWLog(@"keyboard.environment_unavailable",@{@"reason":exception.reason ?: @"exception"});
        }
    }
    return self;
}
- (void)invalidate {
    if(!_key) return;
    @synchronized(MWInputEnvironments) { [MWInputEnvironments removeObjectForKey:_key]; }
    _key=nil;
}
- (void)dealloc { [self invalidate]; }
@end
