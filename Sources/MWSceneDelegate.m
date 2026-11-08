// SPDX-License-Identifier: Apache-2.0
#import "MWSceneDelegate.h"
#import "Platform/MWFloatingHost.h"
#import "UI/MWWorkspaceController.h"
#import "UI/MWPreferences.h"
#import "UI/MWWorkspaceCoordinator.h"
#import "Platform/MWPrivate.h"
#import "Diagnostics/MWDiagnostics.h"

@interface MWOverlayWindow : UIWindow
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
    _floating=[_sceneIdentifier hasPrefix:@"io.github.uiharuxpro4milkyway.overlay."];
    if(_floating && ![MWFloatingHost.shared ownsSceneIdentifier:_sceneIdentifier]) {
        // Cancelled or superseded connection: never create an opaque normal window.
        @try { [[PrivClass(FBSceneManager) sharedInstance] destroyScene:_sceneIdentifier withTransitionContext:nil]; }
        @catch(NSException *exception) { NSLog(@"Discarding stale overlay: %@",exception.reason); }
        return;
    }
    self.window=_floating ? [[MWOverlayWindow alloc] initWithWindowScene:windowScene] : [[UIWindow alloc] initWithWindowScene:windowScene];
    self.window.backgroundColor=UIColor.clearColor;
    self.window.overrideUserInterfaceStyle=MWPreferences.shared.appearance;
    self.window.frame=windowScene.coordinateSpace.bounds;
    if(_floating) [MWWorkspaceCoordinator.shared attachFloatingWindow:self.window];
    else [MWWorkspaceCoordinator.shared attachApplicationWindow:self.window];
    if(_floating) self.window.windowLevel=UIWindowLevelStatusBar+100;
    [self.window makeKeyAndVisible];
    if(_floating) {
        MWFloatingHost.shared.floatingWindow=self.window;
    }
}
- (void)sceneDidDisconnect:(UIScene *)scene {
    (void)scene;
    MWLog(@"host_scene.disconnect",@{@"session":_sceneIdentifier ?: @"none",@"floating":@(_floating)});
    if(_floating) [MWFloatingHost.shared sceneDisconnected:_sceneIdentifier];
    [MWWorkspaceCoordinator.shared detachWindow:self.window]; self.window=nil;
}
- (void)sceneDidEnterBackground:(UIScene *)scene {
    (void)scene;
    MWLog(@"host_scene.background",@{@"session":_sceneIdentifier ?: @"none",@"floating":@(_floating)});
    if(!_floating) { [MWWorkspaceCoordinator.shared setWindow:self.window visible:NO]; self.window.hidden=YES; }
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

