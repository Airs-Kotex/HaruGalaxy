// SPDX-License-Identifier: Apache-2.0
#import "MWSceneDelegate.h"
#import "Platform/MWFloatingHost.h"
#import "UI/MWWorkspaceController.h"
#import "UI/MWPreferences.h"

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
    MWWorkspaceController *_workspace;
    BOOL _floating;
}
- (void)scene:(UIScene *)scene willConnectToSession:(UISceneSession *)session options:(UISceneConnectionOptions *)options {
    (void)options;
    UIWindowScene *windowScene=(UIWindowScene *)scene;
    _floating=[MWFloatingHost.shared ownsSceneIdentifier:session.persistentIdentifier];
    _workspace=[MWWorkspaceController new]; _workspace.floating=_floating;
    self.window=_floating ? [[MWOverlayWindow alloc] initWithWindowScene:windowScene] : [[UIWindow alloc] initWithWindowScene:windowScene];
    self.window.backgroundColor=UIColor.clearColor;
    self.window.overrideUserInterfaceStyle=MWPreferences.shared.appearance;
    self.window.frame=windowScene.coordinateSpace.bounds;
    self.window.rootViewController=_workspace;
    if(_floating) self.window.windowLevel=UIWindowLevelStatusBar+100;
    [self.window makeKeyAndVisible];
    if(_floating) {
        MWFloatingHost.shared.floatingWindow=self.window;
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(stopFloating:) name:MWFloatingHostWillStopNotification object:nil];
    }
}
- (void)sceneDidDisconnect:(UIScene *)scene { (void)scene; [_workspace closeAllWindows]; self.window=nil; }
- (void)sceneDidEnterBackground:(UIScene *)scene {
    (void)scene;
    if(!_floating) self.window.hidden=YES;
}
- (void)sceneWillEnterForeground:(UIScene *)scene { (void)scene; if(!_floating) self.window.hidden=NO; }
- (void)stopFloating:(NSNotification *)notification { (void)notification; [_workspace closeAllWindows]; self.window.hidden=YES; }
- (void)dealloc { [[NSNotificationCenter defaultCenter] removeObserver:self]; }
@end

