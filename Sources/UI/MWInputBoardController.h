// SPDX-License-Identifier: Apache-2.0
#import <UIKit/UIKit.h>

@interface MWInputBoardController : UIViewController
@property(nonatomic,copy) NSString *applicationName;
@property(nonatomic,copy) void (^completionHandler)(BOOL copied);
@property(nonatomic,copy) void (^originalApplicationHandler)(void);
- (void)invalidateInput;
@end
