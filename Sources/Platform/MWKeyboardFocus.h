// SPDX-License-Identifier: Apache-2.0
#import <UIKit/UIKit.h>

@interface MWKeyboardFocus : NSObject
+ (instancetype)shared;
- (void)registerGuest:(NSString *)identifier processIdentifier:(pid_t)pid scene:(id)scene;
- (void)unregisterGuest:(NSString *)identifier;
- (void)releaseGuest:(NSString *)identifier;
- (void)focusGuest:(NSString *)identifier inWindow:(UIWindow *)window;
- (void)refreshGuest:(NSString *)identifier inWindow:(UIWindow *)window;
- (void)focusHostWindow:(UIWindow *)window reason:(NSString *)reason;
- (void)setSuspended:(BOOL)suspended;
- (void)releaseForWindow:(UIWindow *)window;
- (NSDictionary *)snapshot;
- (BOOL)hasPendingCleanup;
@end
