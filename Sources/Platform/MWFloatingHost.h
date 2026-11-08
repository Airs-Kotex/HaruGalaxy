// SPDX-License-Identifier: Apache-2.0
#import <UIKit/UIKit.h>
FOUNDATION_EXPORT NSString *const MWFloatingHostWillStopNotification;
FOUNDATION_EXPORT NSString *const MWFloatingHostFailedNotification;

@interface MWFloatingHost : NSObject
@property(nonatomic,readonly,getter=isEnabled) BOOL enabled;
@property(nonatomic,copy,readonly) NSString *sceneIdentifier;
@property(nonatomic,weak) UIWindow *floatingWindow;
+ (instancetype)shared;
- (BOOL)setEnabled:(BOOL)enabled fromScene:(UIWindowScene *)scene error:(NSError **)error;
- (BOOL)ownsSceneIdentifier:(NSString *)identifier;
@end

