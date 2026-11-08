// SPDX-License-Identifier: Apache-2.0
#import "MWEdgeHandle.h"
#import "MWPreferences.h"
#import "../Core/MWWindowModel.h"
#import "../Diagnostics/MWDiagnostics.h"

@implementation MWEdgeHandle {
    UIView *_tab;
    UIImageView *_symbol;
    CGRect _viewport;
    BOOL _right, _expanded, _dragging;
    double _position;
    NSUInteger _idleGeneration;
}
- (instancetype)init {
    if((self=[super initWithFrame:CGRectMake(0,0,44,48)])) {
        NSUserDefaults *defaults=NSUserDefaults.standardUserDefaults;
        _right=![defaults boolForKey:@"edgeHandleLeft"];
        _position=[defaults objectForKey:@"edgeHandlePosition"] ? [defaults doubleForKey:@"edgeHandlePosition"] : 0.35;
        _tab=[UIView new]; _tab.userInteractionEnabled=NO;
        _tab.backgroundColor=[UIColor colorWithRed:0.04 green:0.48 blue:0.52 alpha:0.9];
        _tab.layer.cornerRadius=8; _tab.layer.cornerCurve=kCACornerCurveContinuous;
        [self addSubview:_tab];
        _symbol=[[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"square.stack.3d.up.fill"]];
        _symbol.tintColor=UIColor.whiteColor; _symbol.contentMode=UIViewContentModeScaleAspectFit;
        _symbol.userInteractionEnabled=NO; [_tab addSubview:_symbol];
        [self addTarget:self action:@selector(tapped) forControlEvents:UIControlEventTouchUpInside];
        [self addGestureRecognizer:[[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(panned:)]];
        [self addGestureRecognizer:[[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(longPressed:)]];
        self.isAccessibilityElement=YES; self.accessibilityTraits=UIAccessibilityTraitButton;
        self.accessibilityLabel=@"边缘应用入口";
        self.accessibilityHint=@"点按展开，再次点按打开应用；长按打开设置；可沿屏幕边缘拖动";
    }
    return self;
}
- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat width=_expanded ? 44 : 8;
    _tab.frame=CGRectMake(_right ? self.bounds.size.width-width : 0,0,width,self.bounds.size.height);
    _tab.layer.maskedCorners=_right ? kCALayerMinXMinYCorner|kCALayerMinXMaxYCorner : kCALayerMaxXMinYCorner|kCALayerMaxXMaxYCorner;
    _symbol.frame=CGRectMake(12,14,20,20); _symbol.alpha=_expanded ? 1 : 0;
}
- (void)applyViewport:(CGRect)viewport {
    _viewport=viewport;
    if(_dragging) return;
    MWRect rect=MWEdgeHandleRect((MWRect){viewport.origin.x,viewport.origin.y,viewport.size.width,viewport.size.height},_right,_position);
    self.frame=CGRectMake(rect.x,rect.y,rect.width,rect.height);
}
- (void)setExpanded:(BOOL)expanded {
    _expanded=expanded; _idleGeneration++;
    MWTrace(@"edge.visibility",@{@"expanded":@(expanded),@"right":@(_right)});
    [self setNeedsLayout];
    [UIView animateWithDuration:MWPreferences.shared.reduceMotion ? 0 : 0.2 animations:^{[self layoutIfNeeded];}];
    if(expanded && !_dragging) {
        NSUInteger generation=_idleGeneration; __weak typeof(self) weakSelf=self;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,3*NSEC_PER_SEC),dispatch_get_main_queue(),^{
            MWEdgeHandle *handle=weakSelf;
            if(handle && generation==handle->_idleGeneration && !handle->_dragging) [handle setExpanded:NO];
        });
    }
}
- (void)tapped {
    if(!_expanded) { [self setExpanded:YES]; return; }
    [self setExpanded:YES];
    if(self.activationHandler) self.activationHandler();
}
- (BOOL)accessibilityActivate {
    [self setExpanded:YES]; if(self.activationHandler) self.activationHandler(); return YES;
}
- (void)longPressed:(UILongPressGestureRecognizer *)gesture {
    if(gesture.state==UIGestureRecognizerStateBegan) { [self setExpanded:YES]; if(self.settingsHandler) self.settingsHandler(); }
}
- (void)panned:(UIPanGestureRecognizer *)gesture {
    if(gesture.state==UIGestureRecognizerStateBegan) { _dragging=YES; [self setExpanded:YES]; }
    CGPoint delta=[gesture translationInView:self.superview]; [gesture setTranslation:CGPointZero inView:self.superview];
    self.center=CGPointMake(MAX(CGRectGetMinX(_viewport)+22,MIN(CGRectGetMaxX(_viewport)-22,self.center.x+delta.x)),
        MAX(CGRectGetMinY(_viewport)+24,MIN(CGRectGetMaxY(_viewport)-24,self.center.y+delta.y)));
    if(gesture.state==UIGestureRecognizerStateEnded || gesture.state==UIGestureRecognizerStateCancelled) {
        _right=self.center.x>=CGRectGetMidX(_viewport);
        _position=(self.frame.origin.y-_viewport.origin.y)/MAX(1,_viewport.size.height-48);
        _dragging=NO;
        [NSUserDefaults.standardUserDefaults setBool:!_right forKey:@"edgeHandleLeft"];
        [NSUserDefaults.standardUserDefaults setDouble:_position forKey:@"edgeHandlePosition"];
        [UIView animateWithDuration:MWPreferences.shared.reduceMotion ? 0 : 0.2 animations:^{[self applyViewport:self->_viewport];}];
        [self setExpanded:YES];
        MWLog(@"edge.position",@{@"right":@(_right),@"position":@(_position)});
    }
}
@end
