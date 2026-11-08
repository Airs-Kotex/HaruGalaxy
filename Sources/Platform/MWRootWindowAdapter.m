// SPDX-License-Identifier: Apache-2.0
// Only windows reached from our binder's _rootView are marked. Other UIKit
// root windows always retain their original layout and hit-testing behavior.
#import "MWRootWindowAdapter.h"
#import "MWPrivate.h"
#import "../Core/MWRuntimeTypes.h"
#import "../Diagnostics/MWDiagnostics.h"
#import <objc/runtime.h>

static char MWRootAdapterKey;
static void (*MWOriginalRootLayout)(id,SEL);
static UIView *(*MWOriginalRootHitTest)(id,SEL,CGPoint,UIEvent *);
static void MWRootLayout(id window,SEL selector) {
    MWOriginalRootLayout(window,selector);
    MWRootWindowAdapter *adapter=objc_getAssociatedObject(window,&MWRootAdapterKey);
    [adapter refresh];
}
static UIView *MWRootHitTest(id window,SEL selector,CGPoint point,UIEvent *event) {
    UIView *original=MWOriginalRootHitTest(window,selector,point,event);
    MWRootWindowAdapter *adapter=objc_getAssociatedObject(window,&MWRootAdapterKey);
    if(!adapter) return original;
    UIWindow *overlay=adapter.overlayWindow;
    if(!overlay || overlay.hidden) return nil;
    CGPoint overlayPoint=[overlay convertPoint:point fromWindow:window];
    // Use our window only to gate empty regions; keep UIKit's native routing
    // result for real controls/guest views rather than cross-window substitution.
    return [overlay hitTest:overlayPoint withEvent:event] ? original : nil;
}

static BOOL MWInstallRootAdapter(void) {
    static BOOL installed=NO;
    if(installed) return YES;
    Class cls=NSClassFromString(@"UIRootSceneWindow");
    Method layout=class_getInstanceMethod(cls,@selector(layoutSubviews));
    Method hit=class_getInstanceMethod(cls,@selector(hitTest:withEvent:));
    if(!layout || !hit || method_getNumberOfArguments(layout)!=2 || method_getNumberOfArguments(hit)!=4) return NO;
    char type[128]={0}; method_getReturnType(layout,type,sizeof(type));
    if(!MWObjCTypeMatches(type,'v')) return NO;
    method_getReturnType(hit,type,sizeof(type));
    if(!MWObjCTypeMatches(type,'@')) return NO;
    method_getArgumentType(hit,2,type,sizeof(type));
    if(!strstr(type,"CGPoint")) return NO;
    MWOriginalRootLayout=(void (*)(id,SEL))method_getImplementation(layout);
    MWOriginalRootHitTest=(UIView *(*)(id,SEL,CGPoint,UIEvent *))method_getImplementation(hit);
    class_replaceMethod(cls,@selector(layoutSubviews),(IMP)MWRootLayout,method_getTypeEncoding(layout));
    class_replaceMethod(cls,@selector(hitTest:withEvent:),(IMP)MWRootHitTest,method_getTypeEncoding(hit));
    installed=YES; return YES;
}

@implementation MWRootWindowAdapter {
    __weak UIView *_root;
    __weak UIWindow *_rootWindow;
}
- (BOOL)attachToRootView:(UIView *)root error:(NSError **)error {
    if(![root isKindOfClass:UIView.class]) {
        if(error) *error=MWError(50,@"系统没有提供可管理的浮窗根视图。"); return NO;
    }
    UIWindow *window=[root isKindOfClass:UIWindow.class] ? (UIWindow *)root : root.window;
    Class rootClass=NSClassFromString(@"UIRootSceneWindow");
    if(!rootClass || ![window isKindOfClass:rootClass] || !MWInstallRootAdapter()) {
        MWLog(@"overlay.root_rejected",@{@"viewClass":NSStringFromClass(root.class),@"windowClass":window ? NSStringFromClass(window.class) : @"none"});
        if(error) *error=MWError(51,@"当前系统的浮窗根窗口不兼容，已保留应用内工作台。"); return NO;
    }
    _root=root; _rootWindow=window;
    objc_setAssociatedObject(window,&MWRootAdapterKey,self,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    MWLog(@"overlay.root_before",@{@"viewClass":NSStringFromClass(root.class),@"windowClass":NSStringFromClass(window.class),
        @"opaque":@(window.opaque),@"layerOpaque":@(window.layer.opaque),@"layerBackgroundAlpha":@(window.layer.backgroundColor ? CGColorGetAlpha(window.layer.backgroundColor) : 0)});
    [self refresh];
    return YES;
}
- (void)refresh {
    _root.opaque=NO; _root.backgroundColor=UIColor.clearColor;
    _root.layer.opaque=NO; _root.layer.backgroundColor=UIColor.clearColor.CGColor;
    _rootWindow.opaque=NO; _rootWindow.backgroundColor=UIColor.clearColor;
    _rootWindow.layer.opaque=NO; _rootWindow.layer.backgroundColor=UIColor.clearColor.CGColor;
}
- (void)setOverlayWindow:(UIWindow *)window {
    _overlayWindow=window;
    window.opaque=NO; window.layer.opaque=NO;
    [self refresh];
    MWLog(@"overlay.root_attached",@{@"overlayClass":window ? NSStringFromClass(window.class) : @"none",
        @"rootOpaque":@(_rootWindow.opaque),@"rootBackgroundAlpha":@(_rootWindow.layer.backgroundColor ? CGColorGetAlpha(_rootWindow.layer.backgroundColor) : 0)});
}
- (void)detach {
    // Keep the marked root clear until its owner has invalidated it.
    _rootWindow.hidden=YES;
    if(objc_getAssociatedObject(_rootWindow,&MWRootAdapterKey)==self) objc_setAssociatedObject(_rootWindow,&MWRootAdapterKey,nil,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    _overlayWindow=nil; _root=nil; _rootWindow=nil;
}
@end
