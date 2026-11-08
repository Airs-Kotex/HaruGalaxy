// SPDX-License-Identifier: Apache-2.0
#import <UIKit/UIKit.h>
@class MWWorkspaceController;
@interface MWWorkspaceCoordinator : NSObject
@property(nonatomic,strong,readonly) MWWorkspaceController *workspace;
+ (instancetype)shared;
- (void)attachApplicationWindow:(UIWindow *)window;
- (void)attachFloatingWindow:(UIWindow *)window;
- (void)detachWindow:(UIWindow *)window;
- (void)setWindow:(UIWindow *)window visible:(BOOL)visible;
@end

