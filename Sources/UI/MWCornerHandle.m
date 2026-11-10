// SPDX-License-Identifier: Apache-2.0
#import "MWCornerHandle.h"
#import "../Core/MWWindowModel.h"
#import "../Diagnostics/MWDiagnostics.h"

@implementation MWCornerHandle {
    BOOL _top, _left;
    BOOL _contact;
    CAShapeLayer *_arc;
}
- (instancetype)initWithCorner:(MWResizeCorner)corner {
    if((self=[super initWithFrame:CGRectMake(0,0,MWCornerTouchSize,MWCornerTouchSize)])) {
        _corner=corner; _top=corner==MWResizeTopLeft || corner==MWResizeTopRight;
        _left=corner==MWResizeTopLeft || corner==MWResizeBottomLeft;
        self.opaque=NO; self.backgroundColor=UIColor.clearColor;
        _arc=[CAShapeLayer layer]; _arc.fillColor=UIColor.clearColor.CGColor;
        _arc.lineCap=kCALineCapRound; _arc.lineWidth=2.5; [self.layer addSublayer:_arc];
        self.tintColor=self.freeform ? UIColor.systemOrangeColor : UIColor.systemTealColor;
        self.isAccessibilityElement=YES; self.accessibilityTraits=UIAccessibilityTraitButton;
        self.accessibilityLabel=@[@"左上：系统原始比例缩放",@"右上：自由缩放",@"左下底边：自由缩放",@"右下底边：系统原始比例缩放"][corner];
        [self updateColor];
    }
    return self;
}
- (BOOL)freeform { return _corner==MWResizeTopRight || _corner==MWResizeBottomLeft; }
- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
    (void)event;
    return CGRectContainsPoint(self.bounds,point); // Dedicated host-only header/footer.
}
- (void)layoutSubviews {
    [super layoutSubviews];
    UIBezierPath *path;
    if(_top) {
        CGFloat radius=MIN(6,MIN(self.bounds.size.width,self.bounds.size.height)/4);
        CGFloat x=self.bounds.size.width/2;
        path=[UIBezierPath bezierPathWithArcCenter:CGPointMake(x,self.bounds.size.height/2)
            radius:radius startAngle:_left ? M_PI : -M_PI_2 endAngle:_left ? M_PI*1.5 : 0 clockwise:YES];
    } else {
        path=[UIBezierPath bezierPath];
        CGFloat middle=CGRectGetMidX(self.bounds),half=MIN(12,self.bounds.size.width/4);
        [path moveToPoint:CGPointMake(middle-half,CGRectGetMidY(self.bounds))];
        [path addLineToPoint:CGPointMake(middle+half,CGRectGetMidY(self.bounds))];
    }
    [CATransaction begin]; [CATransaction setDisableActions:YES]; _arc.frame=self.bounds; _arc.path=path.CGPath; [CATransaction commit];
}
- (void)setDragging:(BOOL)dragging { _dragging=dragging; _arc.lineWidth=dragging ? 3.5 : 2.5; [self updateColor]; }
- (BOOL)beginTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)event {
    (void)touch; (void)event; _contact=YES; [self updateColor];
    MWTrace(@"window.resize_contact",@{@"mode":self.freeform ? @"free" : @"proportional",@"corner":@(_corner)});
    return YES;
}
- (void)endTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)event {
    [super endTrackingWithTouch:touch withEvent:event]; _contact=NO; [self updateColor];
}
- (void)cancelTrackingWithEvent:(UIEvent *)event {
    _contact=NO; [super cancelTrackingWithEvent:event]; [self updateColor];
}
- (void)updateColor {
    _arc.lineWidth=(_dragging || _contact) ? 2.5 : (_top ? 2.5 : 1.5);
    if(!_top) {
        self.backgroundColor=[self.tintColor colorWithAlphaComponent:(_dragging || _contact) ? 0.18 : 0.025];
        self.layer.cornerRadius=4;
    }
    _arc.strokeColor=[[self.tintColor colorWithAlphaComponent:(_dragging || _contact) ? 1 : 0.8] resolvedColorWithTraitCollection:self.traitCollection].CGColor;
}
- (void)traitCollectionDidChange:(UITraitCollection *)previous { [super traitCollectionDidChange:previous]; [self updateColor]; }
@end
