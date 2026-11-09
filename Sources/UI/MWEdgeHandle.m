// SPDX-License-Identifier: Apache-2.0
#import "MWEdgeHandle.h"
#import "MWPreferences.h"
#import "../Core/MWWindowModel.h"
#import "../Core/MWEdgeInteraction.h"
#import "../Diagnostics/MWDiagnostics.h"

@implementation MWEdgeHandle {
    UIView *_tab;
    UIImageView *_symbol;
    UILabel *_badge;
    CGRect _viewport;
    BOOL _right, _expanded, _dragging, _touchActive;
    double _position;
    BOOL _originalRight;
    double _originalPosition;
    CGPoint _dragOrigin, _dragTouch;
    NSUInteger _idleGeneration, _touchGeneration;
    MWEdgeInteraction _interaction;
    UIImpactFeedbackGenerator *_feedback;
    CFTimeInterval _touchStartedAt;
}
- (instancetype)init {
    if((self=[super initWithFrame:CGRectMake(0,0,MWEdgeTouchWidth,MWEdgeTouchHeight)])) {
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
        // One tracking path decides tap, inward pull and hold-to-move. Small
        // finger drift must not make two competing recognizers both fail.
        self.multipleTouchEnabled=NO;
        self.accessibilityIdentifier=@"harugalaxy.edge.entry";
        _feedback=[[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
        self.isAccessibilityElement=YES; self.accessibilityTraits=UIAccessibilityTraitButton;
        self.accessibilityLabel=@"窗口面板";
        self.accessibilityHint=@"轻点或向内短划打开面板；长按振动后拖动移动入口，原地松手也可打开";
        [self applyPreferences];
    }
    return self;
}
- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat width=MIN(self.bounds.size.width,_expanded ? 44 : 12);
    CGFloat height=MIN(60,self.bounds.size.height);
    _tab.frame=CGRectMake(_right ? self.bounds.size.width-width : 0,(self.bounds.size.height-height)/2,width,height);
    _tab.layer.maskedCorners=_right ? kCALayerMinXMinYCorner|kCALayerMinXMaxYCorner : kCALayerMaxXMinYCorner|kCALayerMaxXMaxYCorner;
    _symbol.frame=CGRectMake(12,(height-20)/2,20,20); _symbol.alpha=_expanded ? 1 : 0;
    _badge.frame=CGRectMake(27,3,14,14); _badge.hidden=!_expanded || !_minimizedCount;
}
- (void)setMinimizedCount:(NSUInteger)count {
    if(_minimizedCount==count && _badge.text) return;
    _minimizedCount=count; _badge.text=[NSString stringWithFormat:@"%lu",(unsigned long)count];
    self.accessibilityValue=[NSString stringWithFormat:@"%lu 个已收纳窗口",(unsigned long)count];
    [self setNeedsLayout];
}
- (void)setPanelOpen:(BOOL)panelOpen {
    if(_panelOpen==panelOpen) return;
    _panelOpen=panelOpen;
    [self setExpanded:panelOpen || _touchActive || _dragging || MWPreferences.shared.edgeAlwaysExpanded];
}
- (void)applyPreferences {
    [self setExpanded:_panelOpen || _touchActive || _dragging || MWPreferences.shared.edgeAlwaysExpanded];
}
- (void)applyViewport:(CGRect)viewport {
    if(!CGRectEqualToRect(_viewport,viewport) && _touchActive) [self cancelInteraction];
    _viewport=viewport;
    if(_dragging) return;
    MWRect rect=MWEdgeHandleRect((MWRect){viewport.origin.x,viewport.origin.y,viewport.size.width,viewport.size.height},_right,_position);
    CGRect frame=CGRectMake(rect.x,rect.y,rect.width,rect.height);
    if(!CGRectEqualToRect(frame,self.frame)) self.frame=frame;
}
- (void)setExpanded:(BOOL)expanded {
    expanded=expanded || MWPreferences.shared.edgeAlwaysExpanded;
    _idleGeneration++;
    if(_expanded!=expanded) {
        [self layoutIfNeeded]; _expanded=expanded;
        MWTrace(@"edge.visibility",@{@"expanded":@(expanded),@"right":@(_right)});
        [self setNeedsLayout];
        [UIView animateWithDuration:MWPreferences.shared.reduceMotion ? 0 : 0.16 delay:0
            options:UIViewAnimationOptionAllowUserInteraction|UIViewAnimationOptionBeginFromCurrentState|UIViewAnimationOptionCurveEaseOut
            animations:^{[self layoutIfNeeded];} completion:nil];
    }
    if(expanded && !_touchActive && !_dragging && !_panelOpen && !MWPreferences.shared.edgeAlwaysExpanded) {
        NSUInteger generation=_idleGeneration; __weak typeof(self) weakSelf=self;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,3*NSEC_PER_SEC),dispatch_get_main_queue(),^{
            MWEdgeHandle *handle=weakSelf;
            if(handle && generation==handle->_idleGeneration && !handle->_touchActive && !handle->_dragging && !handle->_panelOpen)
                [handle setExpanded:NO];
        });
    }
}
- (void)activatePanel:(NSString *)reason {
    MWLog(@"edge.activate",@{@"panelOpen":@(_panelOpen),@"reason":reason,
        @"duration":@(MAX(0,CACurrentMediaTime()-_touchStartedAt))});
    if(self.activationHandler) self.activationHandler();
}
- (BOOL)accessibilityActivate {
    [self cancelInteraction]; _touchStartedAt=CACurrentMediaTime();
    [self activatePanel:@"accessibility"]; return YES;
}
- (BOOL)beginTracking:(UITouch *)touch withEvent:(UIEvent *)event {
    (void)event;
    if(_touchActive || !self.enabled || !self.superview) return NO;
    _touchActive=YES; _originalRight=_right; _originalPosition=_position;
    _dragOrigin=self.center; _dragTouch=[touch locationInView:self.superview];
    _touchStartedAt=CACurrentMediaTime();
    MWEdgeTouchBegin(&_interaction,_dragTouch.x,_dragTouch.y,_touchStartedAt,_right,!_panelOpen);
    NSUInteger generation=++_touchGeneration;
    [_feedback prepare]; [self setExpanded:YES];
    MWTrace(@"edge.touch_begin",@{@"right":@(_right),@"panelOpen":@(_panelOpen)});
    __weak typeof(self) weakSelf=self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(0.35*NSEC_PER_SEC)),dispatch_get_main_queue(),^{
        MWEdgeHandle *handle=weakSelf;
        if(!handle || !handle->_touchActive || generation!=handle->_touchGeneration) return;
        unsigned action=MWEdgeTouchHold(&handle->_interaction,CACurrentMediaTime());
        if(action&MWEdgeActionArmed) [handle->_feedback impactOccurred];
    });
    return YES;
}
- (void)applyAction:(unsigned)action atPoint:(CGPoint)point {
    if(action&MWEdgeActionArmed) [_feedback impactOccurred];
    if(action&MWEdgeActionMoveBegin) {
        _dragging=YES;
        _dragTouch=CGPointMake(_interaction.heldX,_interaction.heldY);
        if(self.movementBeganHandler) self.movementBeganHandler();
        MWLog(@"edge.move_begin",@{});
    }
    if(action&MWEdgeActionMove) {
        CGFloat halfWidth=self.bounds.size.width/2,halfHeight=self.bounds.size.height/2;
        self.center=CGPointMake(MAX(CGRectGetMinX(_viewport)+halfWidth,MIN(CGRectGetMaxX(_viewport)-halfWidth,_dragOrigin.x+point.x-_dragTouch.x)),
            MAX(CGRectGetMinY(_viewport)+halfHeight,MIN(CGRectGetMaxY(_viewport)-halfHeight,_dragOrigin.y+point.y-_dragTouch.y)));
    }
    if(action&(MWEdgeActionMoveEnd|MWEdgeActionMoveCancel)) {
        BOOL cancelled=(action&MWEdgeActionMoveCancel)!=0;
        BOOL previousRight=_right;
        _right=cancelled ? _originalRight : self.center.x>=CGRectGetMidX(_viewport);
        _position=cancelled ? _originalPosition : (self.frame.origin.y-_viewport.origin.y)/MAX(1,_viewport.size.height-self.bounds.size.height);
        _dragging=NO;
        if(!cancelled) {
            [NSUserDefaults.standardUserDefaults setBool:!_right forKey:@"edgeHandleLeft"];
            [NSUserDefaults.standardUserDefaults setDouble:_position forKey:@"edgeHandlePosition"];
        }
        if(previousRight!=_right) [self setNeedsLayout];
        [UIView animateWithDuration:MWPreferences.shared.reduceMotion ? 0 : 0.16 delay:0
            options:UIViewAnimationOptionAllowUserInteraction|UIViewAnimationOptionBeginFromCurrentState|UIViewAnimationOptionCurveEaseOut
            animations:^{[self applyViewport:self->_viewport]; [self layoutIfNeeded];} completion:nil];
        if(self.positionChangedHandler) self.positionChangedHandler();
        MWLog(@"edge.move_end",@{@"right":@(_right),@"position":@(_position),@"cancelled":@(cancelled)});
    }
}
- (BOOL)continueTracking:(UITouch *)touch withEvent:(UIEvent *)event {
    (void)event;
    if(!_touchActive) return NO;
    CGPoint point=[touch locationInView:self.superview];
    [self applyAction:MWEdgeTouchUpdate(&_interaction,point.x,point.y,CACurrentMediaTime()) atPoint:point];
    return YES;
}
- (void)endTracking:(UITouch *)touch withEvent:(UIEvent *)event {
    (void)event;
    if(!_touchActive) return;
    if(!touch) { [self cancelInteraction]; return; }
    CGPoint point=[touch locationInView:self.superview];
    unsigned action=MWEdgeTouchEnd(&_interaction,point.x,point.y,CACurrentMediaTime());
    _touchActive=NO; _touchGeneration++;
    [self applyAction:action atPoint:point];
    if(action&MWEdgeActionTap) [self activatePanel:@"tap_or_stationary_hold"];
    else if((action&MWEdgeActionPullOpen) && !_panelOpen) [self activatePanel:@"inward_pull"];
    else MWTrace(@"edge.touch_end",@{@"action":@(action),@"duration":@(CACurrentMediaTime()-_touchStartedAt)});
    [self setExpanded:_panelOpen || _expanded];
}
- (void)cancelTrackingWithEvent:(UIEvent *)event { (void)event; [self cancelInteraction]; }
- (void)cancelInteraction {
    if(!_touchActive && !_dragging) return;
    unsigned action=MWEdgeTouchCancel(&_interaction);
    _touchActive=NO; _touchGeneration++;
    [self applyAction:action atPoint:_dragTouch];
    [self setExpanded:_panelOpen || MWPreferences.shared.edgeAlwaysExpanded];
    MWTrace(@"edge.touch_cancelled",@{});
}
- (void)willMoveToWindow:(UIWindow *)window {
    if(window!=self.window) [self cancelInteraction];
    [super willMoveToWindow:window];
}
- (void)setHidden:(BOOL)hidden {
    if(hidden) [self cancelInteraction];
    [super setHidden:hidden];
}
@end
