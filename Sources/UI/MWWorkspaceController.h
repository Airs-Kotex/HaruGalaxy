// SPDX-License-Identifier: Apache-2.0
#import <UIKit/UIKit.h>
@interface MWWorkspaceController : UIViewController
@property(nonatomic,getter=isFloating) BOOL floating;
- (void)closeAllWindows;
- (void)setHostVisible:(BOOL)visible;
- (void)showMessage:(NSString *)message;
@end

