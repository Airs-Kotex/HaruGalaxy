// SPDX-License-Identifier: Apache-2.0
#import <UIKit/UIKit.h>
FOUNDATION_EXPORT NSString *const MWFloatingHostWillStopNotification;
FOUNDATION_EXPORT NSString *const MWFloatingHostFailedNotification;
FOUNDATION_EXPORT NSString *const MWFloatingHostVisibilityNotification;
FOUNDATION_EXPORT NSString *const MWFloatingHostDidBecomeReadyNotification;

@interface MWFloatingHost : NSObject
@property(nonatomic,readonly,getter=isEnabled) BOOL enabled;
@property(nonatomic,readonly,getter=isReady) BOOL ready;
@property(nonatomic,readonly,getter=isLocked) BOOL locked;
@property(nonatomic,copy,readonly) NSString *sceneIdentifier;
@property(nonatomic,weak) UIWindow *floatingWindow;
+ (instancetype)shared;
- (BOOL)setEnabled:(BOOL)enabled fromScene:(UIWindowScene *)scene error:(NSError **)error;
- (BOOL)ownsSceneIdentifier:(NSString *)identifier;
- (void)sceneDisconnected:(NSString *)identifier;
- (id)protectedDiff:(id)diff forIdentifier:(NSString *)identifier;
- (void)refreshAfterBackgroundTransition;
- (void)setSearchInputSuspended:(BOOL)suspended;
@property(nonatomic,readonly) BOOL backgroundExecutionValid;
@end

