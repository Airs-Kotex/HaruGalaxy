// SPDX-License-Identifier: Apache-2.0
#import "MWGlassSurface.h"

UIColor *MWGlassRowColor(void) {
    return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *traits) {
        if(UIAccessibilityIsReduceTransparencyEnabled()) return UIColor.secondarySystemGroupedBackgroundColor;
        BOOL dark=traits.userInterfaceStyle==UIUserInterfaceStyleDark;
        return dark ? [UIColor colorWithWhite:0.12 alpha:0.48] : [UIColor colorWithWhite:1 alpha:0.48];
    }];
}
UIColor *MWGlassBorderColor(UITraitCollection *traits,BOOL active) {
    BOOL dark=traits.userInterfaceStyle==UIUserInterfaceStyleDark;
    BOOL contrast=traits.accessibilityContrast==UIAccessibilityContrastHigh || UIAccessibilityDarkerSystemColorsEnabled();
    if(active) return [UIColor colorWithRed:0.1 green:0.66 blue:0.65 alpha:contrast ? 0.9 : (dark ? 0.65 : 0.5)];
    return [UIColor colorWithWhite:dark ? 1 : 0 alpha:contrast ? 0.5 : (dark ? 0.24 : 0.13)];
}

@implementation MWGlassSurface {
    CAGradientLayer *_shine;
    CAShapeLayer *_innerRim;
    CGSize _lastSize;
    CGFloat _lastRadius;
}
- (instancetype)initWithCornerRadius:(CGFloat)radius {
    if((self=[super initWithEffect:nil])) {
        _glassCornerRadius=radius; self.opaque=NO; self.backgroundColor=UIColor.clearColor;
        self.clipsToBounds=YES; self.layer.cornerCurve=kCACornerCurveContinuous;
        _shine=[CAGradientLayer layer];
        _shine.startPoint=CGPointMake(0,0); _shine.endPoint=CGPointMake(1,1);
        _shine.locations=@[@0,@0.38,@1];
        [self.contentView.layer insertSublayer:_shine atIndex:0];
        _innerRim=[CAShapeLayer layer]; _innerRim.fillColor=UIColor.clearColor.CGColor;
        _innerRim.lineWidth=0.5;
        [self.contentView.layer insertSublayer:_innerRim above:_shine];
        NSNotificationCenter *center=NSNotificationCenter.defaultCenter;
        [center addObserver:self selector:@selector(refreshGlass) name:UIAccessibilityReduceTransparencyStatusDidChangeNotification object:nil];
        [center addObserver:self selector:@selector(refreshGlass) name:UIAccessibilityDarkerSystemColorsStatusDidChangeNotification object:nil];
        [self refreshGlass];
    }
    return self;
}
- (void)setEmphasized:(BOOL)emphasized {
    if(_emphasized==emphasized) return;
    _emphasized=emphasized; [self refreshGlass];
}
- (void)setGlassCornerRadius:(CGFloat)radius {
    if(_glassCornerRadius==radius) return;
    _glassCornerRadius=MAX(0,radius); [self setNeedsLayout];
}
- (void)refreshGlass {
    BOOL dark=self.traitCollection.userInterfaceStyle==UIUserInterfaceStyleDark;
    BOOL reduced=UIAccessibilityIsReduceTransparencyEnabled();
    BOOL contrast=self.traitCollection.accessibilityContrast==UIAccessibilityContrastHigh || UIAccessibilityDarkerSystemColorsEnabled();
    [CATransaction begin]; [CATransaction setDisableActions:YES];
    self.effect=reduced ? nil : [UIBlurEffect effectWithStyle:contrast ? UIBlurEffectStyleSystemMaterial : UIBlurEffectStyleSystemUltraThinMaterial];
    self.contentView.backgroundColor=reduced ? UIColor.secondarySystemBackgroundColor :
        [UIColor colorWithWhite:dark ? 0 : 1 alpha:contrast ? 0.34 : (dark ? 0.18 : 0.13)];
    self.layer.borderWidth=contrast ? 1 : 0.5;
    self.layer.borderColor=MWGlassBorderColor(self.traitCollection,_emphasized).CGColor;
    _shine.hidden=_innerRim.hidden=reduced;
    _shine.colors=@[(id)[UIColor colorWithWhite:1 alpha:dark ? 0.13 : 0.38].CGColor,
        (id)[UIColor colorWithWhite:1 alpha:0.015].CGColor,
        (id)[UIColor colorWithWhite:0 alpha:dark ? 0.13 : 0.035].CGColor];
    _innerRim.strokeColor=[UIColor colorWithWhite:1 alpha:contrast ? 0.7 : (dark ? 0.27 : 0.7)].CGColor;
    _innerRim.hidden=reduced || self.layer.maskedCorners!=(kCALayerMinXMinYCorner|kCALayerMinXMaxYCorner|kCALayerMaxXMinYCorner|kCALayerMaxXMaxYCorner);
    [CATransaction commit];
    [self setNeedsLayout];
}
- (void)traitCollectionDidChange:(UITraitCollection *)previous {
    [super traitCollectionDidChange:previous]; [self refreshGlass];
}
- (void)layoutSubviews {
    [super layoutSubviews];
    self.layer.cornerRadius=_glassCornerRadius;
    _innerRim.hidden=UIAccessibilityIsReduceTransparencyEnabled() ||
        self.layer.maskedCorners!=(kCALayerMinXMinYCorner|kCALayerMinXMaxYCorner|kCALayerMaxXMinYCorner|kCALayerMaxXMaxYCorner);
    if(CGSizeEqualToSize(_lastSize,self.bounds.size) && _lastRadius==_glassCornerRadius) return;
    _lastSize=self.bounds.size; _lastRadius=_glassCornerRadius;
    [CATransaction begin]; [CATransaction setDisableActions:YES];
    _shine.frame=self.bounds; _innerRim.frame=self.bounds;
    CGRect rim=CGRectInset(self.bounds,1,1);
    _innerRim.path=rim.size.width>0 && rim.size.height>0 ?
        [UIBezierPath bezierPathWithRoundedRect:rim cornerRadius:MAX(0,_glassCornerRadius-1)].CGPath : nil;
    [CATransaction commit];
}
- (void)dealloc { [[NSNotificationCenter defaultCenter] removeObserver:self]; }
@end
