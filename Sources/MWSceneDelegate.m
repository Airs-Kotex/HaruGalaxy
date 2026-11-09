// SPDX-License-Identifier: Apache-2.0
#import "MWSceneDelegate.h"
#import "Platform/MWFloatingHost.h"
#import "UI/MWWorkspaceController.h"
#import "UI/MWPreferences.h"
#import "UI/MWWorkspaceCoordinator.h"
#import "UI/MWEdgeHandle.h"
#import "UI/MWWindowView.h"
#import "Platform/MWKeyboardFocus.h"
#import "Platform/MWPrivate.h"
#import "Diagnostics/MWDiagnostics.h"

@interface MWInputWindow : UIWindow
@end
@implementation MWInputWindow
- (void)sendEvent:(UIEvent *)event {
    if(event.type==UIEventTypeTouches) for(UITouch *touch in [event touchesForWindow:self]) {
        if(touch.phase!=UITouchPhaseBegan && touch.phase!=UITouchPhaseEnded && touch.phase!=UITouchPhaseCancelled) continue;
        BOOL control=NO;
        for(UIView *view=touch.view;view && view!=self;view=view.superview) {
            if([view isKindOfClass:UIControl.class]) control=YES;
            if(touch.phase==UITouchPhaseBegan && !control && [view isKindOfClass:MWWindowView.class]) {
                // The touch has already been hit-tested. Select the guest before
                // forwarding it; never mutate the global hit-testing path.
                [(MWWindowView *)view prepareKeyboardFocus]; break;
            }
            if([view isKindOfClass:MWEdgeHandle.class]) {
                // Only the app-owned entry, never guest touches or keyboard input.
                MWTrace(@"input.edge_delivery",@{@"phase":@(touch.phase),@"windowClass":NSStringFromClass(self.class),
                    @"interactive":@(self.userInteractionEnabled),@"key":@(self.isKeyWindow)});
                break;
            }
        }
    }
    [super sendEvent:event];
}
@end

@interface MWOverlayWindow : MWInputWindow
@end
@implementation MWOverlayWindow
- (BOOL)_allowsOcclusionDetectionOverride { return YES; }
- (BOOL)_extendsScreenSceneLifetime { return YES; }
- (BOOL)_usesWindowServerHitTesting { return YES; }
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *hit=[super hitTest:point withEvent:event];
    return hit==self ? nil : hit;
}
@end

@implementation MWSceneDelegate {
    BOOL _floating;
    NSString *_sceneIdentifier;
}
- (void)scene:(UIScene *)scene willConnectToSession:(UISceneSession *)session options:(UISceneConnectionOptions *)options {
    (void)options;
    UIWindowScene *windowScene=(UIWindowScene *)scene;
    _sceneIdentifier=[session.persistentIdentifier copy];
    MWLog(@"host_scene.connect",@{@"session":_sceneIdentifier ?: @"none"});
    _floating=[_sceneIdentifier hasPrefix:@"io.github.airskotex.harugalaxy.overlay."];
    if(_floating && ![MWFloatingHost.shared ownsSceneIdentifier:_sceneIdentifier]) {
        // Cancelled or superseded connection: never create an opaque normal window.
        @try { [[PrivClass(FBSceneManager) sharedInstance] destroyScene:_sceneIdentifier withTransitionContext:nil]; }
        @catch(NSException *exception) { NSLog(@"Discarding stale overlay: %@",exception.reason); }
        return;
    }
    self.window=_floating ? [[MWOverlayWindow alloc] initWithWindowScene:windowScene] : [[MWInputWindow alloc] initWithWindowScene:windowScene];
    self.window.backgroundColor=UIColor.clearColor;
    self.window.opaque=NO; self.window.layer.opaque=NO;
    self.window.overrideUserInterfaceStyle=MWPreferences.shared.appearance;
    self.window.frame=windowScene.coordinateSpace.bounds;
    if(_floating) {
        // Publish only a transparent, noninteractive scene layer while the
        // binder creates its root window. Do not transfer the workspace or
        // take key status until the host confirms both objects are ready.
        UIViewController *staging=[UIViewController new];
        staging.view.backgroundColor=UIColor.clearColor; staging.view.opaque=NO;
        staging.view.layer.opaque=NO; staging.view.userInteractionEnabled=NO;
        self.window.rootViewController=staging;
        self.window.userInteractionEnabled=NO;
        self.window.windowLevel=UIWindowLevelStatusBar+100;
        self.window.hidden=NO;
        MWFloatingHost.shared.floatingWindow=self.window;
    } else {
        [MWWorkspaceCoordinator.shared attachApplicationWindow:self.window];
        [self.window makeKeyAndVisible];
    }
}
- (void)sceneDidDisconnect:(UIScene *)scene {
    (void)scene;
    MWLog(@"host_scene.disconnect",@{@"session":_sceneIdentifier ?: @"none",@"floating":@(_floating)});
    [MWKeyboardFocus.shared releaseForWindow:self.window];
    if(_floating) [MWFloatingHost.shared sceneDisconnected:_sceneIdentifier];
    [MWWorkspaceCoordinator.shared detachWindow:self.window]; self.window=nil;
}
- (void)sceneDidEnterBackground:(UIScene *)scene {
    (void)scene;
    MWLog(@"host_scene.background",@{@"session":_sceneIdentifier ?: @"none",@"floating":@(_floating)});
    if(!_floating) { [MWKeyboardFocus.shared releaseForWindow:self.window]; [MWWorkspaceCoordinator.shared setWindow:self.window visible:NO]; self.window.hidden=YES; }
    [MWFloatingHost.shared refreshAfterBackgroundTransition];
}
- (void)sceneWillEnterForeground:(UIScene *)scene {
    (void)scene;
    MWLog(@"host_scene.foreground",@{@"session":_sceneIdentifier ?: @"none",@"floating":@(_floating)});
    if(!_floating) { self.window.hidden=NO; [MWWorkspaceCoordinator.shared setWindow:self.window visible:YES]; }
}
- (void)windowScene:(UIWindowScene *)windowScene didUpdateCoordinateSpace:(id<UICoordinateSpace>)previous interfaceOrientation:(UIInterfaceOrientation)orientation traitCollection:(UITraitCollection *)traits {
    (void)previous; (void)orientation; (void)traits;
    MWLog(@"host_scene.geometry",@{@"session":_sceneIdentifier ?: @"none",@"orientation":@(windowScene.interfaceOrientation),@"width":@(windowScene.coordinateSpace.bounds.size.width),@"height":@(windowScene.coordinateSpace.bounds.size.height)});
}
- (void)dealloc { [[NSNotificationCenter defaultCenter] removeObserver:self]; }
@end

