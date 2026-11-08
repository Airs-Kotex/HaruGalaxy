// SPDX-License-Identifier: Apache-2.0
#import <UIKit/UIKit.h>
@interface MWGuestContentView : UIView
@property(nonatomic) CGSize logicalSize;
@property(nonatomic,strong) UIView *guestView;
- (NSDictionary *)geometrySnapshot;
@end
