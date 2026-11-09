// SPDX-License-Identifier: Apache-2.0
#import "MWEdgeHandle.h"
#import "MWPreferences.h"
#import "../Core/MWWindowModel.h"
#import "../Diagnostics/MWDiagnostics.h"

@implementation MWEdgeHandle {
    UIView *_tab;
    UIImageView *_symbol;
    UILabel *_badge;
    CGRect _viewport;
    BOOL _right, _expanded, _dragging;
    double _position;
    BOOL _originalRight;
    double _originalPosition;
    CGPoint _dragOrigin, _dragTouch;
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
        _badge=[UILabel new]; _badge.userInteractionEnabled=NO; _badge.textColor=UIColor.whiteColor;
        _badge.backgroundColor=UIColor.systemOrangeColor; _badge.textAlignment=NSTextAlignmentCenter;
        _badge.font=[UIFont systemFontOfSize:10 weight:UIFontWeightBold]; _badge.layer.cornerRadius=7; _badge.clipsToBounds=YES;
        [_tab addSubview:_badge];
        UILongPressGestureRecognizer *move=[[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(held:)];
        move.minimumPressDuration=0.35; move.allowableMovement=10; move.cancelsTouchesInView=YES;
        [self addGestureRecognizer:move];
        UITapGestureRecognizer *tap=[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapped)];
        [tap requireGestureRecognizerToFail:move]; [self addGestureRecognizer:tap];
        self.isAccessibilityElement=YES; self.accessibilityTraits=UIAccessibilityTraitButton;
        self.accessibilityLabel=@"窗口面板";
        self.accessibilityHint=@"轻点打开窗口面板；长按振动后拖动移动入口";
    }
    return self;
}
- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat width=_expanded ? 44 : 8;
    _tab.frame=CGRectMake(_right ? self.bounds.size.width-width : 0,0,width,self.bounds.size.height);
    _tab.layer.maskedCorners=_right ? kCALayerMinXMinYCorner|kCALayerMinXMaxYCorner : kCALayerMaxXMinYCorner|kCALayerMaxXMaxYCorner;
    _symbol.frame=CGRectMake(12,14,20,20); _symbol.alpha=_expanded ? 1 : 0;
    _badge.frame=CGRectMake(27,3,14,14); _badge.hidden=!_expanded || !_minimizedCount;
}
- (void)setMinimizedCount:(NSUInteger)count {
    _minimizedCount=count; _badge.text=[NSString stringWithFormat:@"%lu",(unsigned long)count];
    self.accessibilityValue=[NSString stringWithFormat:@"%lu 个已收纳窗口",(unsigned long)count];
    [self setNeedsLayout];
}
- (void)setPanelOpen:(BOOL)panelOpen { _panelOpen=panelOpen; [self setExpanded:panelOpen]; }
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
    if(expanded && !_dragging && !_panelOpen) {
        NSUInteger generation=_idleGeneration; __weak typeof(self) weakSelf=self;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,3*NSEC_PER_SEC),dispatch_get_main_queue(),^{
            MWEdgeHandle *handle=weakSelf;
            if(handle && generation==handle->_idleGeneration && !handle->_dragging && !handle->_panelOpen) [handle setExpanded:NO];
        });
    }
}
- (void)tapped {
    MWLog(@"edge.tap",@{@"panelOpen":@(_panelOpen)});
    if(self.activationHandler) self.activationHandler();
}
- (BOOL)accessibilityActivate {
    [self tapped]; return YES;
}
- (void)held:(UILongPressGestureRecognizer *)gesture {
    CGPoint point=[gesture locationInView:self.superview];
    if(gesture.state==UIGestureRecognizerStateBegan) {
        _dragging=YES; _originalRight=_right; _originalPosition=_position;
        _dragOrigin=self.center; _dragTouch=point;
        if(self.movementBeganHandler) self.movementBeganHandler();
        [self setExpanded:YES];
        [[[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight] impactOccurred];
        MWLog(@"edge.move_begin",@{});
    }
    if(gesture.state==UIGestureRecognizerStateChanged) {
        self.center=CGPointMake(MAX(CGRectGetMinX(_viewport)+22,MIN(CGRectGetMaxX(_viewport)-22,_dragOrigin.x+point.x-_dragTouch.x)),
            MAX(CGRectGetMinY(_viewport)+24,MIN(CGRectGetMaxY(_viewport)-24,_dragOrigin.y+point.y-_dragTouch.y)));
    }
    if(gesture.state==UIGestureRecognizerStateEnded || gesture.state==UIGestureRecognizerStateCancelled || gesture.state==UIGestureRecognizerStateFailed) {
        if(!_dragging) return;
        BOOL cancelled=gesture.state!=UIGestureRecognizerStateEnded;
        _right=cancelled ? _originalRight : self.center.x>=CGRectGetMidX(_viewport);
        _position=cancelled ? _originalPosition : (self.frame.origin.y-_viewport.origin.y)/MAX(1,_viewport.size.height-48);
        _dragging=NO;
        if(!cancelled) {
            [NSUserDefaults.standardUserDefaults setBool:!_right forKey:@"edgeHandleLeft"];
            [NSUserDefaults.standardUserDefaults setDouble:_position forKey:@"edgeHandlePosition"];
        }
        [UIView animateWithDuration:MWPreferences.shared.reduceMotion ? 0 : 0.2 animations:^{[self applyViewport:self->_viewport];}];
        [self setExpanded:YES];
        if(self.positionChangedHandler) self.positionChangedHandler();
        MWLog(@"edge.move_end",@{@"right":@(_right),@"position":@(_position),@"cancelled":@(cancelled)});
    }
}
@end
