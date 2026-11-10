// SPDX-License-Identifier: Apache-2.0
#import "MWCornerHandle.h"
#import "../Core/MWWindowModel.h"
#import "../Diagnostics/MWDiagnostics.h"

@implementation MWCornerHandle {
    BOOL _top;
    BOOL _contact;
    CAShapeLayer *_arc;
}
- (instancetype)initAtTop:(BOOL)top {
    if((self=[super initWithFrame:CGRectMake(0,0,MWCornerTouchSize,MWCornerTouchSize)])) {
        _top=top; self.opaque=NO; self.backgroundColor=UIColor.clearColor;
        _arc=[CAShapeLayer layer]; _arc.fillColor=UIColor.clearColor.CGColor;
        _arc.lineCap=kCALineCapRound; _arc.lineWidth=2.5; [self.layer addSublayer:_arc];
        self.tintColor=top ? UIColor.systemOrangeColor : UIColor.systemTealColor;
        self.isAccessibilityElement=YES; self.accessibilityTraits=UIAccessibilityTraitButton;
        self.accessibilityLabel=top ? @"右上弧线：自由缩放" : @"底部细条：系统原始比例缩放";
        [self updateColor];
    }
    return self;
}
- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
    (void)event;
    if(!_top) return CGRectContainsPoint(self.bounds,point); // Dedicated host-only rail.
    return MWCornerHit(point.x,point.y,self.bounds.size.width,self.bounds.size.height,_top);
}
- (void)layoutSubviews {
    [super layoutSubviews];
    CGPoint center=CGPointMake(self.bounds.size.width-11,_top ? 11 : self.bounds.size.height-11);
    UIBezierPath *path=[UIBezierPath bezierPathWithArcCenter:center radius:7 startAngle:_top ? -M_PI_2 : 0 endAngle:_top ? 0 : M_PI_2 clockwise:YES];
    if(!_top) {
        CGFloat middle=CGRectGetMidX(self.bounds),half=MIN(16,self.bounds.size.width/4);
        [path moveToPoint:CGPointMake(middle-half,CGRectGetMidY(self.bounds))];
        [path addLineToPoint:CGPointMake(middle+half,CGRectGetMidY(self.bounds))];
    }
    [CATransaction begin]; [CATransaction setDisableActions:YES]; _arc.frame=self.bounds; _arc.path=path.CGPath; [CATransaction commit];
}
- (void)setDragging:(BOOL)dragging { _dragging=dragging; _arc.lineWidth=dragging ? 3.5 : 2.5; [self updateColor]; }
- (BOOL)beginTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)event {
    (void)touch; (void)event; _contact=YES; [self updateColor];
    MWTrace(@"window.resize_contact",@{@"mode":_top ? @"free" : @"proportional"});
    return YES;
}
- (void)endTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)event {
    [super endTrackingWithTouch:touch withEvent:event]; _contact=NO; [self updateColor];
}
- (void)cancelTrackingWithEvent:(UIEvent *)event {
    _contact=NO; [super cancelTrackingWithEvent:event]; [self updateColor];
}
- (void)updateColor {
    _arc.lineWidth=(_dragging || _contact) ? 3.5 : 2.5;
    if(!_top) {
        self.backgroundColor=[self.tintColor colorWithAlphaComponent:(_dragging || _contact) ? 0.22 : 0.09];
        self.layer.cornerRadius=6;
    }
    _arc.strokeColor=[[self.tintColor colorWithAlphaComponent:(_dragging || _contact) ? 1 : 0.8] resolvedColorWithTraitCollection:self.traitCollection].CGColor;
}
- (void)traitCollectionDidChange:(UITraitCollection *)previous { [super traitCollectionDidChange:previous]; [self updateColor]; }
@end
