// SPDX-License-Identifier: Apache-2.0
#import <UIKit/UIKit.h>
@interface MWCornerHandle : UIControl
- (instancetype)initAtTop:(BOOL)top;
@property(nonatomic) BOOL dragging;
@end
