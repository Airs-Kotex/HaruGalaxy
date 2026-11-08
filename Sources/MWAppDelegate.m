// SPDX-License-Identifier: Apache-2.0
#import "MWAppDelegate.h"
@implementation MWAppDelegate
- (UISceneConfiguration *)application:(UIApplication *)application configurationForConnectingSceneSession:(UISceneSession *)session options:(UISceneConnectionOptions *)options {
    (void)application; (void)options;
    UISceneConfiguration *config=[[UISceneConfiguration alloc] initWithName:@"Workspace" sessionRole:session.role];
    config.delegateClass=NSClassFromString(@"MWSceneDelegate"); return config;
}
@end

