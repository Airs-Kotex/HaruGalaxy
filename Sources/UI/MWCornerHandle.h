// SPDX-License-Identifier: Apache-2.0
#import <UIKit/UIKit.h>
#import "../Core/MWWindowModel.h"
@interface MWCornerHandle : UIControl
- (instancetype)initWithCorner:(MWResizeCorner)corner;
@property(nonatomic,readonly) MWResizeCorner corner;
@property(nonatomic,readonly) BOOL freeform;
@property(nonatomic) BOOL dragging;
@end
