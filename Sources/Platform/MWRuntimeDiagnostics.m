// SPDX-License-Identifier: Apache-2.0
#import "MWRuntimeDiagnostics.h"
#import "../Core/MWRuntimeTypes.h"
#import <objc/runtime.h>
#import <objc/message.h>
#include <string.h>

NSDictionary *MWRuntimeMethodSnapshot(id object,NSString *name) {
    SEL selector=NSSelectorFromString(name);
    Method method=object ? class_getInstanceMethod(object_getClass(object),selector) : NULL;
    const char *encoding=method ? method_getTypeEncoding(method) : NULL;
    return @{@"class":object ? NSStringFromClass(object_getClass(object)) : @"none",
        @"responds":@(object && [object respondsToSelector:selector]),@"methodPresent":@(method!=NULL),
        @"encoding":encoding ? [NSString stringWithUTF8String:encoding] : @"unavailable",
        @"arguments":@(method ? method_getNumberOfArguments(method) : 0)};
}
static BOOL MWDiagnosticGetter(id object,SEL selector,char expected) {
    if(!object || ![object respondsToSelector:selector]) return NO;
    Method method=class_getInstanceMethod(object_getClass(object),selector);
    if(!method || method_getNumberOfArguments(method)!=2) return NO;
    char result[128]={0}; method_getReturnType(method,result,sizeof(result));
    return MWObjCTypeMatches(result,expected);
}
id MWRuntimeObjectValue(id object,NSString *name) {
    @try {
        SEL selector=NSSelectorFromString(name);
        return MWDiagnosticGetter(object,selector,'@') ? ((id(*)(id,SEL))objc_msgSend)(object,selector) : nil;
    } @catch(NSException *exception) { (void)exception; return nil; }
}
id MWRuntimeBoolValue(id object,NSString *name) {
    @try {
        SEL selector=NSSelectorFromString(name);
        if(!MWDiagnosticGetter(object,selector,'B') && !MWDiagnosticGetter(object,selector,'c')) return @"unavailable";
        return @(((BOOL(*)(id,SEL))objc_msgSend)(object,selector));
    } @catch(NSException *exception) { (void)exception; return @"exception"; }
}
id MWRuntimeInsetsValue(id object,NSString *name) {
    @try {
        SEL selector=NSSelectorFromString(name);
        if(!object || ![object respondsToSelector:selector]) return @"unavailable";
        Method method=class_getInstanceMethod(object_getClass(object),selector);
        if(!method || method_getNumberOfArguments(method)!=2) return @"unavailable";
        char result[128]={0}; method_getReturnType(method,result,sizeof(result));
        NSMethodSignature *signature=[object methodSignatureForSelector:selector];
        if(!strstr(result,"UIEdgeInsets") || signature.methodReturnLength!=sizeof(UIEdgeInsets)) return @"unavailable";
        UIEdgeInsets insets=((UIEdgeInsets(*)(id,SEL))objc_msgSend)(object,selector);
        return @[@(insets.top),@(insets.left),@(insets.bottom),@(insets.right)];
    } @catch(NSException *exception) { (void)exception; return @"exception"; }
}
id MWRuntimeIntegerValue(id object,NSString *name) {
    @try {
        SEL selector=NSSelectorFromString(name);
        if(MWDiagnosticGetter(object,selector,'q')) return @(((long long(*)(id,SEL))objc_msgSend)(object,selector));
        if(MWDiagnosticGetter(object,selector,'Q')) return @(((unsigned long long(*)(id,SEL))objc_msgSend)(object,selector));
        if(MWDiagnosticGetter(object,selector,'i')) return @(((int(*)(id,SEL))objc_msgSend)(object,selector));
        if(MWDiagnosticGetter(object,selector,'I')) return @(((unsigned int(*)(id,SEL))objc_msgSend)(object,selector));
        return @"unavailable";
    } @catch(NSException *exception) { (void)exception; return @"exception"; }
}
id MWRuntimeRectValue(id object,NSString *name) {
    @try {
        SEL selector=NSSelectorFromString(name);
        if(!object || ![object respondsToSelector:selector]) return @"unavailable";
        Method method=class_getInstanceMethod(object_getClass(object),selector);
        if(!method || method_getNumberOfArguments(method)!=2) return @"unavailable";
        char result[128]={0}; method_getReturnType(method,result,sizeof(result));
        NSMethodSignature *signature=[object methodSignatureForSelector:selector];
        if(!strstr(result,"CGRect") || signature.methodReturnLength!=sizeof(CGRect)) return @"unavailable";
        CGRect r=((CGRect(*)(id,SEL))objc_msgSend)(object,selector);
        if(!isfinite(r.origin.x) || !isfinite(r.origin.y) || !isfinite(r.size.width) || !isfinite(r.size.height)) return @"invalid";
        return @[@(r.origin.x),@(r.origin.y),@(r.size.width),@(r.size.height)];
    } @catch(NSException *exception) { (void)exception; return @"exception"; }
}
NSDictionary *MWDiagnosticWindow(UIWindow *window) {
    if(!window) return @{@"present":@NO};
    return @{@"present":@YES,@"class":NSStringFromClass(window.class),@"hidden":@(window.hidden),@"alpha":@(window.alpha),
        @"key":@(window.isKeyWindow),@"level":@(window.windowLevel),@"interactive":@(window.userInteractionEnabled),
        @"width":@(window.bounds.size.width),@"height":@(window.bounds.size.height),
        @"frame":@[@(window.frame.origin.x),@(window.frame.origin.y),@(window.frame.size.width),@(window.frame.size.height)],
        @"safeInsets":@[@(window.safeAreaInsets.top),@(window.safeAreaInsets.left),@(window.safeAreaInsets.bottom),@(window.safeAreaInsets.right)],
        @"scene":window.windowScene.session.persistentIdentifier ?: @"none",
        @"sceneState":@(window.windowScene ? window.windowScene.activationState : UISceneActivationStateUnattached)};
}
