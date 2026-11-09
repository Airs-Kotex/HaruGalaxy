// SPDX-License-Identifier: Apache-2.0
#import <UIKit/UIKit.h>

// Liquid Glass-inspired chrome using APIs available on TrollStore iOS versions.
// It is deliberately separate from guest content and never alters hit testing.
@interface MWGlassSurface : UIVisualEffectView
@property(nonatomic) BOOL emphasized;
@property(nonatomic) CGFloat glassCornerRadius;
- (instancetype)initWithCornerRadius:(CGFloat)radius;
@end

FOUNDATION_EXPORT UIColor *MWGlassRowColor(void);
FOUNDATION_EXPORT UIColor *MWGlassBorderColor(UITraitCollection *traits, BOOL active);
