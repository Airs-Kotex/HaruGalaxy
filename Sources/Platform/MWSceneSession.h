// SPDX-License-Identifier: Apache-2.0
#import <UIKit/UIKit.h>
@interface MWSceneSession : NSObject
@property(nonatomic,copy,readonly) NSString *bundleIdentifier;
@property(nonatomic,copy,readonly) NSString *sceneIdentifier;
@property(nonatomic,strong,readonly) UIView *contentView;
@property(nonatomic,copy) void (^failureHandler)(NSError *error);
@property(nonatomic,copy) void (^inputRequestHandler)(void);
- (instancetype)initWithBundleIdentifier:(NSString *)bundleIdentifier;
- (void)startWithSize:(CGSize)size completion:(void (^)(NSError *error))completion;
- (void)updateSize:(CGSize)size orientation:(UIInterfaceOrientation)orientation safeAreaInsets:(UIEdgeInsets)insets;
- (void)setVisible:(BOOL)visible;
- (void)requestKeyboardFocusInWindow:(UIWindow *)window;
- (void)refreshKeyboardFocusInWindow:(UIWindow *)window;
- (void)releaseKeyboardFocus;
- (void)close;
- (void)closeForOriginalApplication:(void (^)(NSError *error))completion;
- (NSError *)originalApplicationHandoffIssue;
- (NSDictionary *)inputDiagnosticSnapshotWithCapabilities:(BOOL)capabilities;
@end

