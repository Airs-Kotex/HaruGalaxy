// SPDX-License-Identifier: Apache-2.0
// InterviewOpus compatibility, 2026-11-19. UIKit's presenter owns a background
// distinct from presentationView.backgroundColor. Configure its source context.
#import "MWAssistantPresenterBackdrop.h"
#import "../Core/MWAssistantVideoArea.h"
#import <objc/runtime.h>
#import <objc/message.h>
#include <string.h>

static BOOL MWBackdropMethod(id object,SEL selector,const char *result,const char *argument) {
    if (!object || ![object respondsToSelector:selector]) return NO;
    Method method=class_getInstanceMethod(object_getClass(object),selector);
    if (!method || method_getNumberOfArguments(method)!=(argument ? 3u : 2u)) return NO;
    char encoding[32]={0}; method_getReturnType(method,encoding,sizeof(encoding));
    if (strcmp(encoding,result)) return NO;
    if (argument) {
        method_getArgumentType(method,2,encoding,sizeof(encoding));
        if (strcmp(encoding,argument)) return NO;
    }
    return YES;
}
static id MWBackdropObject(id object,NSString *name) {
    SEL selector=NSSelectorFromString(name);
    @try {
        return MWBackdropMethod(object,selector,"@",NULL) ? ((id(*)(id,SEL))objc_msgSend)(object,selector) : nil;
    } @catch (NSException *exception) { (void)exception; return nil; }
}
static id MWBackdropAlpha(id color) {
    if (![color isKindOfClass:UIColor.class]) return @"unavailable-or-default";
    return @(CGColorGetAlpha(((UIColor *)color).CGColor));
}
static NSDictionary *MWBackdropContext(id context) {
    return @{@"hostingAlpha":MWBackdropAlpha(MWBackdropObject(context,@"backgroundColorWhileHosting")),
             @"notHostingAlpha":MWBackdropAlpha(MWBackdropObject(context,@"backgroundColorWhileNotHosting"))};
}
static NSDictionary *MWBackdropView(id object) {
    if (![object isKindOfClass:UIView.class]) return @{@"available":@NO};
    UIView *view=object;
    return @{@"available":@YES,@"class":NSStringFromClass(view.class),@"alpha":@(view.alpha),@"hidden":@(view.hidden),
        @"backgroundAlpha":MWBackdropAlpha(view.backgroundColor),@"opaque":@(view.opaque),
        @"layerBackgroundAlpha":@(view.layer.backgroundColor ? CGColorGetAlpha(view.layer.backgroundColor) : 0)};
}
NSDictionary *MWAssistantPresenterBackdropSnapshot(id presenter) {
    id view=MWBackdropObject(presenter,@"presentationView");
    id container=MWBackdropObject(view,@"hostContainerView");
    return @{@"presenterContext":MWBackdropContext(MWBackdropObject(presenter,@"presentationContext")),
        @"viewContext":MWBackdropContext(MWBackdropObject(view,@"currentPresentationContext")),
        @"containerContext":MWBackdropContext(MWBackdropObject(container,@"_presentationContext")),
        @"presentationBackground":MWBackdropView(MWBackdropObject(view,@"backgroundView")),
        @"containerBackground":MWBackdropView(MWBackdropObject(container,@"_backgroundView")),
        @"meaning":@"context-and-background-readback-not-video-verification"};
}
NSDictionary *MWApplyAssistantPresenterBackdrop(id presenter,NSString *bundle) {
    if (!MWIsInterviewAssistant(bundle.UTF8String)) return @{@"status":@"not-assistant"};
    if (!NSThread.isMainThread) return @{@"status":@"wrong-thread"};
    SEL modify=NSSelectorFromString(@"modifyPresentationContext:");
    NSDictionary *before=MWAssistantPresenterBackdropSnapshot(presenter);
    if (!MWBackdropMethod(presenter,modify,"v","@?")) return @{@"status":@"presenter-api-unavailable",@"before":before};
    __block NSString *status=@"context-callback-not-invoked";
    @try {
        void (^update)(id)=^(id context) {
            SEL hosting=NSSelectorFromString(@"setBackgroundColorWhileHosting:");
            SEL idle=NSSelectorFromString(@"setBackgroundColorWhileNotHosting:");
            if (!MWBackdropMethod(context,hosting,"v","@") || !MWBackdropMethod(context,idle,"v","@")) {
                status=@"context-api-unavailable"; return;
            }
            ((void(*)(id,SEL,id))objc_msgSend)(context,hosting,UIColor.clearColor);
            ((void(*)(id,SEL,id))objc_msgSend)(context,idle,UIColor.clearColor);
            status=@"requested";
        };
        ((void(*)(id,SEL,id))objc_msgSend)(presenter,modify,update);
    } @catch (NSException *exception) { (void)exception; status=@"context-update-exception"; }
    NSDictionary *after=MWAssistantPresenterBackdropSnapshot(presenter);
    if ([status isEqual:@"requested"]) {
        NSDictionary *context=after[@"presenterContext"];
        status=[context[@"hostingAlpha"] isEqual:@0] && [context[@"notHostingAlpha"] isEqual:@0] ? @"clear-readback" : @"readback-not-clear";
    }
    return @{@"status":status,@"before":before,@"after":after};
}
