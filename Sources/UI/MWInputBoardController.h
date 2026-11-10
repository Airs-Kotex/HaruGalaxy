// SPDX-License-Identifier: Apache-2.0
#import <UIKit/UIKit.h>

@interface MWInputBoardController : UIViewController
@property(nonatomic,copy) void (^completionHandler)(BOOL copied);
- (void)invalidateInput;
@end
