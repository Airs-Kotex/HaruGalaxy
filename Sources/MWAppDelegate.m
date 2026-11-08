// SPDX-License-Identifier: Apache-2.0
#import "MWAppDelegate.h"
#import "Diagnostics/MWDiagnostics.h"
#import "Platform/MWFloatingHost.h"
@implementation MWAppDelegate
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options {
    (void)application; (void)options; [MWDiagnostics.shared start]; return YES;
}
- (void)applicationDidEnterBackground:(UIApplication *)application {
    (void)application; [MWFloatingHost.shared refreshAfterBackgroundTransition];
}
- (void)applicationDidBecomeActive:(UIApplication *)application {
    (void)application; MWLog(@"application.active",@{@"overlayEnabled":@(MWFloatingHost.shared.enabled),@"backgroundValid":@(MWFloatingHost.shared.backgroundExecutionValid)});
}
- (UISceneConfiguration *)application:(UIApplication *)application configurationForConnectingSceneSession:(UISceneSession *)session options:(UISceneConnectionOptions *)options {
    (void)application; (void)options;
    UISceneConfiguration *config=[[UISceneConfiguration alloc] initWithName:@"Workspace" sessionRole:session.role];
    config.delegateClass=NSClassFromString(@"MWSceneDelegate"); return config;
}
@end

