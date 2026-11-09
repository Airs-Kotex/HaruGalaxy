// SPDX-License-Identifier: Apache-2.0
#import "MWApplicationActivation.h"
#import "MWPrivate.h"
#import "../Core/MWRuntimeTypes.h"
#import <objc/runtime.h>

BOOL MWRequestOwnApplicationForeground(NSError **error) {
    NSCAssert(NSThread.isMainThread,@"Application activation is main-thread owned");
    MWLoadPrivateFrameworks();
    NSString *bundle=NSBundle.mainBundle.bundleIdentifier;
    Class cls=NSClassFromString(@"LSApplicationWorkspace");
    SEL selector=@selector(openApplicationWithBundleID:);
    Method method=class_getInstanceMethod(cls,selector);
    char type[64]={0};
    if(method) method_getReturnType(method,type,sizeof(type));
    BOOL valid=method && method_getNumberOfArguments(method)==3 &&
        (MWObjCTypeMatches(type,'B') || MWObjCTypeMatches(type,'c'));
    if(valid) { method_getArgumentType(method,2,type,sizeof(type)); valid=MWObjCTypeMatches(type,'@'); }
    if(!bundle.length || !valid || ![cls respondsToSelector:@selector(defaultWorkspace)]) {
        if(error) *error=MWError(60,@"当前系统没有可用的主应用打开接口。"); return NO;
    }
    @try {
        LSApplicationWorkspace *workspace=[cls defaultWorkspace];
        BOOL accepted=[workspace respondsToSelector:selector] && [workspace openApplicationWithBundleID:bundle];
        if(!accepted && error) *error=MWError(61,@"系统未接受打开初春星河的请求。");
        return accepted;
    } @catch(NSException *exception) {
        if(error) *error=MWError(62,[NSString stringWithFormat:@"打开初春星河失败：%@",exception.reason ?: @"未知异常"]);
        return NO;
    }
}
