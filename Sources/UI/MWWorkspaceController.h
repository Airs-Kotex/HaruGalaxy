// SPDX-License-Identifier: Apache-2.0
#import <UIKit/UIKit.h>
@interface MWWorkspaceController : UIViewController
@property(nonatomic,getter=isFloating) BOOL floating;
- (void)closeAllWindows;
- (void)showMessage:(NSString *)message;
@end

