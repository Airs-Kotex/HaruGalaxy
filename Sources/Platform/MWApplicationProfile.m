// SPDX-License-Identifier: Apache-2.0
#import "MWApplicationProfile.h"
#import "MWPrivate.h"
#import "MWRuntimeDiagnostics.h"
#import "../Core/MWRuntimeTypes.h"
#import <objc/runtime.h>
#import <objc/message.h>
#include <string.h>

static BOOL MWProfileMethod(id object,SEL selector,const char *args) {
    if(!object || ![object respondsToSelector:selector]) return NO;
    Method method=class_getInstanceMethod(object_getClass(object),selector);
    if(!method || method_getNumberOfArguments(method)!=strlen(args)+2) return NO;
    char type[128]={0}; method_getReturnType(method,type,sizeof(type));
    if(!MWObjCTypeMatches(type,'@')) return NO;
    for(unsigned i=0;i<strlen(args);i++) {
        method_getArgumentType(method,i+2,type,sizeof(type));
        if(!MWObjCTypeMatches(type,args[i])) return NO;
    }
    return YES;
}
static id MWProfileValue(id proxy,NSString *key,Class cls) {
    return ((id(*)(id,SEL,id,Class))objc_msgSend)(proxy,NSSelectorFromString(@"objectForInfoDictionaryKey:ofClass:"),key,cls);
}
static id MWProfileString(id value) {
    return [value isKindOfClass:NSString.class] ? [value substringToIndex:MIN(128,[value length])] : @"unavailable";
}
NSDictionary *MWApplicationProfile(NSString *bundle) {
    NSMutableDictionary *result=[@{@"bundle":bundle ?: @"", @"metadataAvailable":@NO} mutableCopy];
    @try {
        MWLoadPrivateFrameworks();
        Class cls=NSClassFromString(@"LSApplicationProxy"); SEL lookup=NSSelectorFromString(@"applicationProxyForIdentifier:");
        if(!bundle.length || !MWProfileMethod(cls,lookup,"@")) { result[@"reason"]=@"proxy_lookup_unavailable"; return result; }
        id proxy=((id(*)(id,SEL,id))objc_msgSend)(cls,lookup,bundle);
        if(!proxy) { result[@"reason"]=@"proxy_missing"; return result; }
        result[@"version"]=MWProfileString(MWRuntimeObjectValue(proxy,@"shortVersionString"));
        result[@"build"]=MWProfileString(MWRuntimeObjectValue(proxy,@"bundleVersion"));
        SEL info=NSSelectorFromString(@"objectForInfoDictionaryKey:ofClass:");
        if(!MWProfileMethod(proxy,info,"@#")) { result[@"reason"]=@"plist_accessor_unavailable"; return result; }
        id manifest=MWProfileValue(proxy,@"UIApplicationSceneManifest",NSDictionary.class);
        result[@"metadataAvailable"]=@YES;
        result[@"sceneManifest"]=[manifest isKindOfClass:NSDictionary.class] ? @"present" : @"absent";
        id multiple=[manifest isKindOfClass:NSDictionary.class] ? manifest[@"UIApplicationSupportsMultipleScenes"] : nil;
        result[@"supportsMultipleScenes"]=[multiple isKindOfClass:NSNumber.class] ? multiple : @"not_declared";
        result[@"sceneConfigurationsPresent"]=@([manifest isKindOfClass:NSDictionary.class] &&
            [manifest[@"UISceneConfigurations"] isKindOfClass:NSDictionary.class]);
        result[@"minimumOS"]=MWProfileString(MWProfileValue(proxy,@"MinimumOSVersion",NSString.class));
        id fullscreen=MWProfileValue(proxy,@"UIRequiresFullScreen",NSNumber.class);
        result[@"requiresFullScreen"]=[fullscreen isKindOfClass:NSNumber.class] ? fullscreen : @"not_declared";
        id orientations=MWProfileValue(proxy,@"UISupportedInterfaceOrientations",NSArray.class);
        NSMutableArray *allowed=[NSMutableArray array];
        if([orientations isKindOfClass:NSArray.class]) for(id value in orientations) {
            if(allowed.count>=4) break;
            if([value isKindOfClass:NSString.class] && [@[@"UIInterfaceOrientationPortrait",@"UIInterfaceOrientationPortraitUpsideDown",
                @"UIInterfaceOrientationLandscapeLeft",@"UIInterfaceOrientationLandscapeRight"] containsObject:value]) [allowed addObject:value];
        }
        result[@"declaredOrientations"]=allowed;
    } @catch(NSException *exception) {
        result[@"metadataAvailable"]=@NO; result[@"reason"]=@"metadata_exception";
        result[@"exception"]=exception.name ?: @"unknown";
    }
    return result;
}
