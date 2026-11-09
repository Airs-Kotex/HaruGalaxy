// SPDX-License-Identifier: Apache-2.0
#import "MWCornerHandle.h"
#import "../Core/MWWindowModel.h"

@implementation MWCornerHandle {
    BOOL _top;
    CAShapeLayer *_arc;
}
- (instancetype)initAtTop:(BOOL)top {
    if((self=[super initWithFrame:CGRectMake(0,0,28,28)])) {
        _top=top; self.opaque=NO; self.backgroundColor=UIColor.clearColor;
        _arc=[CAShapeLayer layer]; _arc.fillColor=UIColor.clearColor.CGColor;
        _arc.lineCap=kCALineCapRound; _arc.lineWidth=2.5; [self.layer addSublayer:_arc];
        self.tintColor=top ? UIColor.systemOrangeColor : UIColor.systemTealColor;
        self.isAccessibilityElement=YES; self.accessibilityTraits=UIAccessibilityTraitButton;
        self.accessibilityLabel=top ? @"右上弧线：自由缩放" : @"右下弧线：系统原始比例缩放";
        [self updateColor];
    }
    return self;
}
- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
    (void)event;
    return MWCornerHit(point.x,point.y,self.bounds.size.width,self.bounds.size.height,_top);
}
- (void)layoutSubviews {
    [super layoutSubviews];
    CGPoint center=CGPointMake(self.bounds.size.width-16,_top ? 16 : self.bounds.size.height-16);
    UIBezierPath *path=[UIBezierPath bezierPathWithArcCenter:center radius:12 startAngle:_top ? -M_PI_2 : 0 endAngle:_top ? 0 : M_PI_2 clockwise:YES];
    [CATransaction begin]; [CATransaction setDisableActions:YES]; _arc.frame=self.bounds; _arc.path=path.CGPath; [CATransaction commit];
}
- (void)setDragging:(BOOL)dragging { _dragging=dragging; _arc.lineWidth=dragging ? 3.5 : 2.5; [self updateColor]; }
- (void)updateColor { _arc.strokeColor=[[self.tintColor colorWithAlphaComponent:_dragging ? 1 : 0.8] resolvedColorWithTraitCollection:self.traitCollection].CGColor; }
- (void)traitCollectionDidChange:(UITraitCollection *)previous { [super traitCollectionDidChange:previous]; [self updateColor]; }
@end
