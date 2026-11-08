// SPDX-License-Identifier: Apache-2.0
#import "MWPrivate.h"

void MWLoadPrivateFrameworks(void) {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        for (NSString *name in @[@"CoreServices", @"FrontBoard", @"RunningBoardServices", @"SpringBoardServices"]) {
            NSString *path=[NSString stringWithFormat:@"/System/Library/PrivateFrameworks/%@.framework/%@",name,name];
            if(!dlopen(path.UTF8String,RTLD_NOW|RTLD_GLOBAL)) {
                NSString *publicPath=[NSString stringWithFormat:@"/System/Library/Frameworks/%@.framework/%@",name,name];
                dlopen(publicPath.UTF8String,RTLD_NOW|RTLD_GLOBAL);
            }
        }
    });
}

NSError *MWError(NSInteger code, NSString *message) {
    return [NSError errorWithDomain:@"UiharuXPro4MilkyWay" code:code
                           userInfo:@{NSLocalizedDescriptionKey:message ?: @"无法完成窗口操作"}];
}

NSString *MWSceneCapabilityIssue(void) {
    MWLoadPrivateFrameworks();
    NSDictionary *classMethods=@{
        @"FBSceneManager":@[@"sharedInstance"],
        @"FBProcessManager":@[@"sharedInstance"],
        @"RBSProcessIdentity":@[@"identityForEmbeddedApplicationIdentifier:"],
        @"RBSProcessPredicate":@[@"predicateMatchingIdentity:"],
        @"RBSProcessHandle":@[@"handleForPredicate:error:"],
        @"FBSMutableSceneDefinition":@[@"definition"],
        @"FBSSceneIdentity":@[@"identityForIdentifier:"],
        @"FBSSceneClientIdentity":@[@"identityForProcessIdentity:"],
        @"UIApplicationSceneSpecification":@[@"specification"],
        @"FBSMutableSceneParameters":@[@"parametersForSpecification:"]
    };
    for (NSString *name in classMethods) {
        Class cls=NSClassFromString(name);
        for (NSString *selector in classMethods[name]) {
            if(!cls || ![cls respondsToSelector:NSSelectorFromString(selector)])
                return [NSString stringWithFormat:@"当前系统缺少应用场景接口：%@。",name];
        }
    }
    NSDictionary *instanceMethods=@{
        @"FBApplicationProcessLaunchTransaction":@[@"initWithProcessIdentity:executionContextProvider:",@"setCompletionBlock:",@"begin"],
        @"FBMutableProcessExecutionContext":@[@"setIdentity:",@"setLaunchIntent:"],
        @"FBSceneManager":@[@"createSceneWithDefinition:initialParameters:",@"destroyScene:withTransitionContext:"],
        @"FBProcessManager":@[@"launchProcessWithContext:",@"registerProcessForAuditToken:"],
        @"UIMutableApplicationSceneSettings":@[@"setForeground:",@"setFrame:",@"setDisplayConfiguration:"],
        @"UIMutableApplicationSceneClientSettings":@[@"setInterfaceOrientation:"]
    };
    for(NSString *name in instanceMethods) {
        Class cls=NSClassFromString(name);
        for(NSString *selector in instanceMethods[name])
            if(!cls || ![cls instancesRespondToSelector:NSSelectorFromString(selector)])
                return [NSString stringWithFormat:@"当前系统的 %@ 接口不兼容。",name];
    }
    return nil;
}

