// SPDX-License-Identifier: Apache-2.0
// Intercepts this app's own client only. Unlike dropping a system update,
// forwarding a normalized diff preserves unrelated changes and the completion ABI.
#import "MWSceneUpdateGuard.h"
#import "MWFloatingHost.h"
#import "../Diagnostics/MWDiagnostics.h"
#import <objc/runtime.h>
#import "../Core/MWRuntimeTypes.h"

typedef void (*MWSceneUpdateIMP)(id,SEL,id,id,id,id);
static MWSceneUpdateIMP MWOriginalUpdate;
static void MWGuardedUpdate(id client,SEL selector,id identifier,id diff,id context,id completion) {
    id effective=diff;
    if([identifier isKindOfClass:NSString.class]) effective=[MWFloatingHost.shared protectedDiff:diff forIdentifier:identifier];
    MWOriginalUpdate(client,selector,identifier,effective,context,completion);
}

BOOL MWInstallSceneUpdateGuard(void) {
    static BOOL installed=NO;
    if(installed) return YES;
    Class cls=NSClassFromString(@"FBSWorkspaceScenesClient");
    SEL selector=NSSelectorFromString(@"sceneID:updateWithSettingsDiff:transitionContext:completion:");
    Method method=class_getInstanceMethod(cls,selector);
    if(!method || method_getNumberOfArguments(method)!=6) { MWLog(@"guard.unavailable",@{@"reason":@"method/arity"}); return NO; }
    MWLog(@"guard.method_abi",@{@"encoding":[NSString stringWithUTF8String:method_getTypeEncoding(method)] ?: @"unknown"});
    char result[32]={0}; method_getReturnType(method,result,sizeof(result));
    if(!MWObjCTypeMatches(result,'v')) { MWLog(@"guard.unavailable",@{@"reason":@"return signature",@"encoding":[NSString stringWithUTF8String:result] ?: @"unknown"}); return NO; }
    for(unsigned i=2;i<6;i++) {
        char type[32]={0}; method_getArgumentType(method,i,type,sizeof(type));
        if(!MWObjCTypeMatches(type,'@')) { MWLog(@"guard.unavailable",@{@"reason":@"argument signature",@"argument":@(i)}); return NO; }
    }
    MWOriginalUpdate=(MWSceneUpdateIMP)method_getImplementation(method);
    class_replaceMethod(cls,selector,(IMP)MWGuardedUpdate,method_getTypeEncoding(method));
    installed=YES; MWLog(@"guard.installed",@{@"scope":@"own active overlay scene; original called once"}); return YES;
}
