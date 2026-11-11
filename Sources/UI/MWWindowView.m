// SPDX-License-Identifier: Apache-2.0
#import "MWWindowView.h"
#import "../Core/MWSceneGeometry.h"
#import "MWPreferences.h"
#import "MWGuestContentView.h"
#import "MWCornerHandle.h"
#import "MWGlassSurface.h"
#import "MWWindowControlImages.h"
#import "../Diagnostics/MWDiagnostics.h"
#import "../Core/MWGuestPolicy.h"

static MWRect MWFromCGRect(CGRect r) { return (MWRect){r.origin.x,r.origin.y,r.size.width,r.size.height}; }
static CGRect MWToCGRect(MWRect r) { return CGRectMake(r.x,r.y,r.width,r.height); }
static NSArray *MWRectFields(CGRect r) { return @[@(r.origin.x),@(r.origin.y),@(r.size.width),@(r.size.height)]; }

@interface MWGeometryDisplayTarget : NSObject
@property(nonatomic,weak) MWWindowView *owner;
- (void)tick:(CADisplayLink *)link;
@end
@interface MWWindowView () <UIGestureRecognizerDelegate>
- (void)flushFrameGeometry:(CADisplayLink *)link;
@end
@implementation MWGeometryDisplayTarget
- (void)tick:(CADisplayLink *)link { [self.owner flushFrameGeometry:link]; }
@end
@implementation MWWindowView {
    UIView *_surface, *_content;
    MWGlassSurface *_bar, *_inputRail;
    UILabel *_message;
    UIButton *_closeButton, *_minimize, *_maximize, *_retry, *_parkButton;
    UIControl *_parkedShield;
    UIImageView *_restoreMark;
    MWCornerHandle *_resize, *_freeResize, *_aspectTopLeft, *_freeBottomLeft;
    UIActivityIndicatorView *_spinner;
    MWWindowModel _model;
    CGRect _viewport, _gestureFrame;
    CGSize _lastSize;
    UIInterfaceOrientation _lastOrientation;
    UIView *_guestView;
    BOOL _hostHidden;
    NSString *_failureMessage;
    CGSize _logicalSize;
    MWGuestContentView *_guestHost;
    MWGuestCanvasState _canvasState, _gestureCanvasState;
    MWWindowModel _gestureModel;
    BOOL _resizing, _dragging, _snapArmed, _geometryUpdatePending;
    MWSnapTarget _snapCandidate;
    NSUInteger _snapGeneration, _geometryGeneration;
    CGSize _shadowSize;
    BOOL _shadowMaximized;
    CADisplayLink *_geometryDisplayLink;
    NSUInteger _resizeSceneUpdates;
    CFTimeInterval _resizeStartedAt;
    NSUInteger _deliveredTouchStarts;
    UIEdgeInsets _lastSafeInsets;
    uint64_t _touchCapture;
    NSUInteger _touchRecords;
    MWWindowParking _parking;
    CGSize _parkedLogicalSize;
    BOOL _resizeActivated;
    BOOL _parkWhenReady;
    UIInterfaceOrientation _workspaceOrientation;
    UIInterfaceOrientation _layoutGuestOrientation;
    UIEdgeInsets _workspaceSafeInsets;
    NSString *_userCloseStatus;
    BOOL _userClosePending;
}
@synthesize model=_model;

- (instancetype)initWithApplication:(MWApplication *)application frame:(CGRect)frame {
    if((self=[super initWithFrame:frame])) {
        _application=application; _model=MWWindowCreate(MWFromCGRect(frame));
        _logicalSize=UIScreen.mainScreen.bounds.size;
        _model.aspectRatio=_logicalSize.width/MAX(1,_logicalSize.height);
        self.backgroundColor=UIColor.clearColor;
        self.layer.shadowColor=UIColor.blackColor.CGColor; self.layer.shadowOpacity=0.2;
        self.layer.shadowRadius=18; self.layer.shadowOffset=CGSizeMake(0,8);
        _surface=[UIView new]; _surface.backgroundColor=UIColor.clearColor;
        _surface.layer.cornerRadius=18; _surface.layer.cornerCurve=kCACornerCurveContinuous;
        _surface.clipsToBounds=YES; _surface.layer.borderWidth=1;
        [self addSubview:_surface];
        _content=[UIView new]; _content.backgroundColor=UIColor.secondarySystemBackgroundColor; _content.clipsToBounds=YES; [_surface addSubview:_content];
        _guestHost=[MWGuestContentView new]; [_content addSubview:_guestHost];
        _bar=[[MWGlassSurface alloc] initWithCornerRadius:0];
        [_surface addSubview:_bar];
        _inputRail=[[MWGlassSurface alloc] initWithCornerRadius:0]; [_surface addSubview:_inputRail];
        _closeButton=[self button:@"xmark" label:@"关闭小窗" color:UIColor.systemRedColor action:@selector(requestClose) x:0];
        _minimize=[self button:@"minus" label:@"最小化" color:UIColor.systemOrangeColor action:@selector(requestMinimize) x:28];
        _maximize=[self button:@"arrow.up.left.and.arrow.down.right" label:@"最大化或恢复" color:UIColor.systemGreenColor action:@selector(toggleMaximize) x:56];
        _parkButton=[self button:@"pip.enter" label:@"挂起到右上角小窗" color:UIColor.systemBlueColor action:@selector(requestPark) x:84];
        [_parkButton setImage:MWParkingControlImage(NO) forState:UIControlStateNormal];
        _parkButton.accessibilityIdentifier=@"harugalaxy.window.park";
        _spinner=[[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
        [_content addSubview:_spinner];
        _message=[UILabel new]; _message.numberOfLines=0; _message.textAlignment=NSTextAlignmentCenter;
        _message.font=[UIFont systemFontOfSize:14]; _message.textColor=UIColor.secondaryLabelColor;
        [_content addSubview:_message];
        _retry=[UIButton buttonWithType:UIButtonTypeSystem]; [_retry setTitle:@"重试打开" forState:UIControlStateNormal];
        [_retry addTarget:self action:@selector(retry) forControlEvents:UIControlEventTouchUpInside];
        [_content addSubview:_retry];
        _resize=[[MWCornerHandle alloc] initWithCorner:MWResizeBottomRight]; [_surface addSubview:_resize];
        _freeResize=[[MWCornerHandle alloc] initWithCorner:MWResizeTopRight]; [_surface addSubview:_freeResize];
        _aspectTopLeft=[[MWCornerHandle alloc] initWithCorner:MWResizeTopLeft]; [_surface addSubview:_aspectTopLeft];
        _freeBottomLeft=[[MWCornerHandle alloc] initWithCorner:MWResizeBottomLeft]; [_surface addSubview:_freeBottomLeft];
        UIPanGestureRecognizer *drag=[[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(drag:)];
        drag.delegate=self; drag.maximumNumberOfTouches=1; [_bar addGestureRecognizer:drag];
        UITapGestureRecognizer *doubleTap=[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(toggleMaximize)];
        doubleTap.numberOfTapsRequired=2; doubleTap.delegate=self; [_bar addGestureRecognizer:doubleTap];
        UITapGestureRecognizer *focus=[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(focus)];
        focus.delegate=self; [focus requireGestureRecognizerToFail:doubleTap]; [_bar addGestureRecognizer:focus];
        for(MWCornerHandle *handle in @[_resize,_freeResize,_aspectTopLeft,_freeBottomLeft]) {
            UIPanGestureRecognizer *pan=[[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(resize:)];
            pan.maximumNumberOfTouches=1; pan.delegate=self; [handle addGestureRecognizer:pan];
        }
        _parkedShield=[UIControl new]; _parkedShield.hidden=YES;
        _parkedShield.backgroundColor=[UIColor.blackColor colorWithAlphaComponent:0.02];
        _parkedShield.accessibilityLabel=@"还原挂起窗口"; _parkedShield.accessibilityTraits=UIAccessibilityTraitButton;
        [_parkedShield addTarget:self action:@selector(requestRestore) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:_parkedShield];
        _restoreMark=[[UIImageView alloc] initWithImage:MWParkingControlImage(YES)];
        _restoreMark.tintColor=UIColor.whiteColor; _restoreMark.backgroundColor=[UIColor.blackColor colorWithAlphaComponent:0.35];
        _restoreMark.layer.cornerRadius=4; [_parkedShield addSubview:_restoreMark];
        [self setActive:YES]; [self updateStatus:nil];
        MWLog(@"window.controls_installed",@{@"bundle":application.bundleIdentifier,@"layout":@"four_corners_flush_snap_v2",
            @"parkButton":@(_parkButton!=nil),@"parkImage":@([_parkButton imageForState:UIControlStateNormal]!=nil),@"applicationTitle":@NO});
    }
    return self;
}
- (UIButton *)button:(NSString *)symbol label:(NSString *)label color:(UIColor *)color action:(SEL)action x:(CGFloat)x {
    UIButton *button=[UIButton buttonWithType:UIButtonTypeSystem];
    button.frame=CGRectMake(x,0,28,MWTitleHeight); button.tintColor=color;
    [button setImage:[UIImage systemImageNamed:symbol withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:11 weight:UIImageSymbolWeightBold]] forState:UIControlStateNormal];
    button.accessibilityLabel=label; [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    [_bar.contentView addSubview:button]; return button;
}
- (void)layoutSubviews {
    [super layoutSubviews];
    [self updateGuestOrientationGeometry];
    CGFloat titleInset=0;
    if(self.window && self.superview) {
        MWWindowModel layoutModel=_model;
        layoutModel.frame=MWFromCGRect(self.frame);
        MWWindowTitleLayout title=MWWindowTitlePlacement(layoutModel,MWFromCGRect(_viewport),_workspaceSafeInsets.top);
        if(!CGRectEqualToRect(self.frame,MWToCGRect(title.frame))) {
            _model.frame=title.frame; self.frame=MWToCGRect(title.frame);
        }
        titleInset=title.titleInset;
    }
    _surface.frame=self.bounds;
    BOOL full=_model.maximized && !self.isParked;
    _surface.layer.cornerRadius=full ? 0 : (self.isParked ? 12 : 18);
    _surface.layer.borderWidth=full ? 0 : 1;
    _bar.hidden=full || self.isParked;
    CGFloat leading=MAX(0,_workspaceSafeInsets.left-self.frame.origin.x);
    CGFloat trailing=MAX(0,CGRectGetMaxX(self.frame)-(CGRectGetMaxX(_viewport)-_workspaceSafeInsets.right));
    MWWindowControls controls=MWWindowControlRects(MWFromCGRect(self.bounds),titleInset,leading,trailing);
    _bar.frame=CGRectMake(controls.topLeft.x,controls.topLeft.y,
        controls.topRight.x+controls.topRight.width-controls.topLeft.x,controls.topLeft.height);
    UIButton *buttons[]={_closeButton,_minimize,_maximize,_parkButton};
    for(NSUInteger i=0;i<4;i++) {
        CGRect frame=MWToCGRect(controls.buttons[i]); frame.origin.x-=_bar.frame.origin.x; frame.origin.y-=_bar.frame.origin.y;
        buttons[i].frame=frame;
    }
    _content.frame=MWToCGRect(MWWindowContentRect(MWFromCGRect(self.bounds),_bar.frame.origin.y,full || self.isParked));
    _inputRail.frame=MWToCGRect(MWWindowRailRect(MWFromCGRect(self.bounds),full || self.isParked));
    _inputRail.hidden=full || _model.state!=MWWindowVisible;
    CGSize systemSize=[self systemCanvasSize];
    int workspace=(int)(_workspaceOrientation ?: self.window.windowScene.interfaceOrientation),guest=(int)[self guestOrientation];
    MWRect available=MWGuestCanvasForOrientation(MWFromCGRect(_content.bounds),
        workspace,guest);
    MWResizeMode mode=_model.maximized ? _model.restoreResizeMode : _model.resizeMode;
    MWRect initial=_model.maximized ? MWWindowContentRect((MWRect){0,0,_model.restoreFrame.width,_model.restoreFrame.height},0,false) : MWFromCGRect(_content.bounds);
    MWRect system={0,0,systemSize.width,systemSize.height};
    MWRect saved=MWGuestCanvasUpdate(&_canvasState,initial,system,workspace,guest,mode==MWResizeProportional,_session!=nil);
    MWRect canvas=MWGuestCanvas(available,saved,system,_model.maximized || _model.snapTarget!=MWSnapNone,_compatibleCanvas);
    if(_session && !_model.maximized && !self.isParked) _canvasState.windowCanvas=canvas;
    _logicalSize=CGSizeMake(canvas.width,canvas.height);
    if(self.isParked) _logicalSize=_parkedLogicalSize;
    _guestHost.frame=_content.bounds;
    _guestHost.logicalSize=_logicalSize;
    [_guestHost layoutIfNeeded];
    _spinner.center=CGPointMake(CGRectGetMidX(_content.bounds),CGRectGetMidY(_content.bounds)-32);
    _message.frame=CGRectMake(16,MAX(12,CGRectGetMidY(_content.bounds)-16),MAX(1,_content.bounds.size.width-32),72);
    _retry.frame=CGRectMake(20,MIN(_content.bounds.size.height-48,CGRectGetMaxY(_message.frame)),MAX(1,_content.bounds.size.width-40),44);
    _resize.frame=MWToCGRect(controls.bottomRight); _freeBottomLeft.frame=MWToCGRect(controls.bottomLeft);
    _freeResize.frame=MWToCGRect(controls.topRight); _aspectTopLeft.frame=MWToCGRect(controls.topLeft);
    _resize.hidden=_freeResize.hidden=_aspectTopLeft.hidden=_freeBottomLeft.hidden=_model.maximized || _model.state!=MWWindowVisible;
    [_surface bringSubviewToFront:_inputRail];
    for(MWCornerHandle *handle in @[_resize,_freeResize,_aspectTopLeft,_freeBottomLeft]) [_surface bringSubviewToFront:handle];
    _parkedShield.hidden=!self.isParked; _parkedShield.frame=self.bounds;
    _restoreMark.frame=CGRectMake(MAX(0,self.bounds.size.width-24),4,20,20);
    if(!CGSizeEqualToSize(_shadowSize,self.bounds.size) || _shadowMaximized!=_model.maximized) {
        _shadowSize=self.bounds.size; _shadowMaximized=_model.maximized;
        self.layer.shadowPath=[UIBezierPath bezierPathWithRoundedRect:self.bounds cornerRadius:full ? 0 : (self.isParked ? 12 : 18)].CGPath;
    }
    UIInterfaceOrientation orientation=[self guestOrientation];
    if(!CGSizeEqualToSize(_lastSize,_logicalSize) || _lastOrientation!=orientation ||
       !UIEdgeInsetsEqualToEdgeInsets(_lastSafeInsets,[self guestSafeInsets])) {
        // During a resize UIKit scales our presentation container immediately.
        // Commit any safe-area change once at the end, with the same canvas.
        if(!_resizing) { if(_dragging) [self scheduleSceneGeometry]; else [self submitSceneGeometry]; }
    }
}
- (CGRect)renderedGuestRectInWindow {
    MWContentTransform t=MWFitContent(_logicalSize.width,_logicalSize.height,_guestHost.bounds.size.width,_guestHost.bounds.size.height);
    return [_guestHost convertRect:CGRectMake(t.x,t.y,_logicalSize.width*t.scale,_logicalSize.height*t.scale) toView:self.window];
}
- (UIEdgeInsets)guestSafeInsets {
    if(!self.window || self.isParked) return UIEdgeInsetsZero;
    CGRect safe=UIEdgeInsetsInsetRect(self.window.bounds,self.window.safeAreaInsets);
    // Convert both rectangles into the guest host's axes. The workspace may
    // be rotated relative to UIWindowScene when system rotation is locked.
    safe=[_guestHost convertRect:safe fromView:self.window];
    MWContentTransform t=MWFitContent(_logicalSize.width,_logicalSize.height,_guestHost.bounds.size.width,_guestHost.bounds.size.height);
    MWRect rendered={t.x,t.y,_logicalSize.width*t.scale,_logicalSize.height*t.scale};
    MWInsets insets=MWGuestSafeInsets(rendered,MWFromCGRect(safe),_logicalSize.width,_logicalSize.height);
    return UIEdgeInsetsMake(insets.top,insets.left,insets.bottom,insets.right);
}
- (void)safeAreaInsetsDidChange {
    [super safeAreaInsetsDidChange]; [self setNeedsLayout];
}
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    if(self.hidden || self.alpha<=0.01 || !self.userInteractionEnabled || ![self pointInside:point withEvent:event]) return nil;
    // Resolve only the local handles before descending into the remote scene.
    // Their rectangles sit entirely in host chrome; no cross-window substitution.
    MWCornerHandle *handles[]={_resize,_freeResize,_aspectTopLeft,_freeBottomLeft};
    for(NSUInteger i=0;i<4;i++) {
        MWCornerHandle *handle=handles[i];
        if(handle && !handle.hidden && handle.userInteractionEnabled) {
            UIView *hit=[handle hitTest:[handle convertPoint:point fromView:self] withEvent:event];
            if(hit) return hit;
        }
    }
    return [super hitTest:point withEvent:event];
}
- (void)scheduleSceneGeometry {
    if(_geometryUpdatePending) return;
    _geometryUpdatePending=YES;
    if(!_geometryDisplayLink) {
        MWGeometryDisplayTarget *target=[MWGeometryDisplayTarget new]; target.owner=self;
        _geometryDisplayLink=[CADisplayLink displayLinkWithTarget:target selector:@selector(tick:)];
        _geometryDisplayLink.preferredFramesPerSecond=30;
        [_geometryDisplayLink addToRunLoop:NSRunLoop.mainRunLoop forMode:NSRunLoopCommonModes];
    }
    _geometryDisplayLink.paused=NO;
}
- (void)flushFrameGeometry:(CADisplayLink *)link {
    link.paused=YES;
    if(!_geometryUpdatePending || _model.state==MWWindowClosed) return;
    _geometryUpdatePending=NO;
    [self submitSceneGeometry];
}
- (void)submitSceneGeometry {
    if(_resizing) return;
    UIInterfaceOrientation orientation=[self guestOrientation];
    UIEdgeInsets insets=[self guestSafeInsets];
    if(CGSizeEqualToSize(_lastSize,_logicalSize) && _lastOrientation==orientation && UIEdgeInsetsEqualToEdgeInsets(_lastSafeInsets,insets)) return;
    _lastSize=_logicalSize; _lastOrientation=orientation; _lastSafeInsets=insets;
    if(_resizeActivated) _resizeSceneUpdates++;
    [_session updateSize:_logicalSize orientation:_lastOrientation safeAreaInsets:insets];
}
- (void)commitSceneGeometry {
    _geometryGeneration++; _geometryUpdatePending=NO; _geometryDisplayLink.paused=YES;
    [self setNeedsLayout]; [self layoutIfNeeded]; [self submitSceneGeometry];
}
- (void)start {
    // This first layout may precede the declared guest orientation. It must not
    // establish a canvas that the session's first layout would rotate again.
    [self layoutIfNeeded];
    _session=[[MWSceneSession alloc] initWithBundleIdentifier:_application.bundleIdentifier];
    [self applyExecutionPolicy];
    __weak typeof(self) weakSelf=self;
    _session.failureHandler=^(NSError *error) { [weakSelf failed:error]; };
    _session.presentationGeometryHandler=^{
        MWWindowView *view=weakSelf;
        if(!view || view->_model.state==MWWindowClosed) return;
        if([view guestOrientation]!=view->_layoutGuestOrientation) {
            [view cancelInteractions];
            [view setNeedsLayout]; [view layoutIfNeeded];
        }
        [view->_guestHost setNeedsLayout]; [view->_guestHost layoutIfNeeded];
    };
    _session.startupStatusHandler=^(NSString *status) {
        MWWindowView *view=weakSelf;
        if(view && view->_model.state==MWWindowLoading) view->_message.text=status;
    };
    _session.inputRequestHandler=^{
        MWWindowView *view=weakSelf;
        // Guest notifications can be delayed or caused by autofocus. They may
        // refresh only the already-selected visible window, never steal input
        // from a different guest or the host's presented picker.
        if(view && view.active && !view->_hostHidden && !view.hidden && !view.window.rootViewController.presentedViewController)
            [view.session refreshKeyboardFocusInWindow:view.window];
    };
    [self setNeedsLayout]; [self layoutIfNeeded];
    [_session updateSize:_logicalSize orientation:[self guestOrientation] safeAreaInsets:[self guestSafeInsets]];
    [_session startWithSize:_logicalSize completion:^(NSError *error) {
        MWWindowView *view=weakSelf;
        if(!view || view->_model.state==MWWindowClosed) return;
        if(error) { [view failed:error]; return; }
        if(!MWWindowApply(&view->_model,MWEventReady)) return;
        UIView *content=view.session.contentView;
        [view->_guestView removeFromSuperview]; view->_guestView=content;
        view->_guestHost.guestView=content;
        [view setNeedsLayout]; [view layoutIfNeeded];
        [view logContentGeometry:@"attached"];
        [view updateStatus:nil];
        if(view->_parkWhenReady) { view->_parkWhenReady=NO; [view park]; }
        if(view.stateHandler) view.stateHandler();
        if(view.active && !view->_hostHidden && !view.hidden && !view.window.rootViewController.presentedViewController)
            [view.session requestKeyboardFocusInWindow:view.window];
    }];
}
- (void)failed:(NSError *)error {
    [self unpark];
    [self cancelInteractions];
    if(!MWWindowApply(&_model,MWEventFailed)) return;
    _guestHost.guestView=nil; [_guestView removeFromSuperview]; _guestView=nil;
    self.hidden=NO;
    [self updateStatus:error.localizedDescription];
    if(self.stateHandler) self.stateHandler();
}
- (void)retry {
    if(!MWWindowApply(&_model,MWEventRetry)) return;
    _guestHost.guestView=nil; [_guestView removeFromSuperview]; _guestView=nil; [_session close]; _session=nil;
    [self updateStatus:nil]; [self start];
}
- (void)updateStatus:(NSString *)error {
    if(_userCloseStatus) {
        _message.text=_userCloseStatus; _message.hidden=NO; _retry.hidden=YES;
        [_spinner stopAnimating];
        _minimize.enabled=_maximize.enabled=_parkButton.enabled=NO;
        _closeButton.enabled=!_userClosePending;
        _resize.hidden=_freeResize.hidden=_aspectTopLeft.hidden=_freeBottomLeft.hidden=_inputRail.hidden=YES;
        return;
    }
    BOOL loading=_model.state==MWWindowLoading;
    if(error.length) _failureMessage=[error copy];
    if(_model.state!=MWWindowFailed) _failureMessage=nil;
    _message.text=_model.state==MWWindowFailed ? (_failureMessage ?: @"小窗暂时不可用，请重试。") : @"正在打开应用…";
    _message.hidden=!loading && _model.state!=MWWindowFailed;
    _retry.hidden=_model.state!=MWWindowFailed;
    if(loading) [_spinner startAnimating]; else [_spinner stopAnimating];
    _minimize.enabled=_maximize.enabled=_parkButton.enabled=(_model.state==MWWindowVisible);
    _resize.hidden=_freeResize.hidden=_aspectTopLeft.hidden=_freeBottomLeft.hidden=_model.maximized || _model.state!=MWWindowVisible;
    _inputRail.hidden=_model.maximized || _model.state!=MWWindowVisible;
}
- (void)setActive:(BOOL)active {
    if(!active) [_session releaseKeyboardFocus];
    if(_active==active && _surface.layer.borderColor) return;
    _active=active;
    _surface.layer.borderColor=MWGlassBorderColor(self.traitCollection,active).CGColor;
    _bar.emphasized=active;
    _inputRail.emphasized=active;
    self.layer.shadowOpacity=active ? 0.19 : 0.1;
}
- (void)traitCollectionDidChange:(UITraitCollection *)previous {
    [super traitCollectionDidChange:previous];
    _surface.layer.borderColor=MWGlassBorderColor(self.traitCollection,_active).CGColor;
}
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)recognizer shouldReceiveTouch:(UITouch *)touch {
    if([recognizer.view isKindOfClass:MWCornerHandle.class]) return YES;
    // A pan beginning over title-bar buttons cancels the button's tap. Narrow
    // windows must still have a usable drag area when controls fill the bar.
    if(recognizer.view==_bar && [recognizer isKindOfClass:UIPanGestureRecognizer.class]) return YES;
    for(UIView *view=touch.view;view && view!=_bar;view=view.superview)
        if([view isKindOfClass:UIControl.class]) return NO;
    return YES;
}
- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gesture {
    (void)gesture;
    return !_dragging && !_resizing && !self.isParked && _model.state!=MWWindowClosed && _model.state!=MWWindowMinimized;
}
- (void)drag:(UIPanGestureRecognizer *)gesture {
    if(_model.maximized || _model.state==MWWindowClosed || _model.state==MWWindowMinimized) return;
    if(gesture.state==UIGestureRecognizerStateBegan) {
        [self layoutIfNeeded];
        _dragging=YES; _gestureModel=_model; _gestureCanvasState=_canvasState;
        [self detachFromSnap]; _gestureFrame=self.frame; [self focus];
    }
    if(!_dragging) return;
    CGPoint delta=[gesture translationInView:self.superview];
    CGRect frame=_gestureFrame; frame.origin.x+=delta.x; frame.origin.y+=delta.y;
    if(gesture.state==UIGestureRecognizerStateChanged || gesture.state==UIGestureRecognizerStateBegan) {
        _model.frame=MWMoveRect(MWFromCGRect(_gestureFrame),delta.x,delta.y,MWFromCGRect(_viewport));
        self.frame=MWToCGRect(_model.frame);
        [self setNeedsLayout]; // Moving can cross a system safe-area boundary.
        [self updateSnapCandidate:_model.resizeMode==MWResizeFree ? MWSnapTargetForDrag(MWFromCGRect(_viewport),MWFromCGRect(_gestureFrame),MWFromCGRect(frame)) : MWSnapNone];
    }
    if(gesture.state==UIGestureRecognizerStateEnded || gesture.state==UIGestureRecognizerStateCancelled || gesture.state==UIGestureRecognizerStateFailed) {
        if(!_dragging) return;
        BOOL cancelled=gesture.state!=UIGestureRecognizerStateEnded;
        if(!cancelled) {
            MWSnapTarget finalTarget=_model.resizeMode==MWResizeFree ? MWSnapTargetForDrag(MWFromCGRect(_viewport),MWFromCGRect(_gestureFrame),MWFromCGRect(frame)) : MWSnapNone;
            if(finalTarget!=_snapCandidate) [self updateSnapCandidate:finalTarget];
        }
        if(cancelled) { _model=_gestureModel; _canvasState=_gestureCanvasState; }
        else if(_snapArmed) {
            MWWindowSnap(&_model,_snapCandidate,MWFromCGRect(_viewport));
            MWLog(@"window.snap_committed",@{@"bundle":_application.bundleIdentifier,@"target":@(_snapCandidate)});
        }
        _dragging=NO; [self updateSnapCandidate:MWSnapNone]; self.frame=MWToCGRect(_model.frame);
        [self commitSceneGeometry]; if(!cancelled) [self geometryChanged];
        if(self.stateHandler) self.stateHandler();
    }
}
- (void)updateSnapCandidate:(MWSnapTarget)target {
    if(target==_snapCandidate) return;
    _snapCandidate=target; _snapArmed=NO; NSUInteger generation=++_snapGeneration;
    if(self.snapPreviewHandler) self.snapPreviewHandler(CGRectZero,NO);
    if(target==MWSnapNone || !_dragging || _model.state!=MWWindowVisible) return;
    __weak typeof(self) weakSelf=self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(0.18*NSEC_PER_SEC)),dispatch_get_main_queue(),^{
        MWWindowView *view=weakSelf;
        if(!view || generation!=view->_snapGeneration || !view->_dragging || view->_model.state!=MWWindowVisible) return;
        view->_snapArmed=YES;
        if(view.snapPreviewHandler) view.snapPreviewHandler(MWToCGRect(MWHalfScreenRect(MWFromCGRect(view->_viewport),target)),YES);
        [[[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight] impactOccurred];
        MWTrace(@"window.snap_preview",@{@"bundle":view.application.bundleIdentifier,@"target":@(target)});
    });
}
- (void)resize:(UIPanGestureRecognizer *)gesture {
    if(_model.maximized || _model.state!=MWWindowVisible) return;
    MWCornerHandle *handle=(MWCornerHandle *)gesture.view;
    BOOL free=handle.freeform;
    if(gesture.state==UIGestureRecognizerStateBegan) {
        [self layoutIfNeeded];
        _gestureModel=_model; _gestureCanvasState=_canvasState;
        _gestureFrame=self.frame; _resizing=YES; _resizeActivated=NO;
        _resizeStartedAt=CACurrentMediaTime(); _resizeSceneUpdates=0;
    }
    if(!_resizing) return;
    CGPoint delta=[gesture translationInView:self.superview];
    BOOL terminal=gesture.state==UIGestureRecognizerStateEnded || gesture.state==UIGestureRecognizerStateCancelled || gesture.state==UIGestureRecognizerStateFailed;
    if(!_resizeActivated) {
        if(gesture.state==UIGestureRecognizerStateCancelled || gesture.state==UIGestureRecognizerStateFailed ||
           !MWResizeDragActivated(delta.x,delta.y)) {
            if(terminal) {
                _resizing=NO;
                [self commitSceneGeometry];
                MWTrace(@"window.resize_ignored",@{@"bundle":_application.bundleIdentifier,@"reason":@"below_drag_threshold_or_cancelled"});
            }
            return;
        }
        _resizeActivated=YES;
        _canvasState.windowCanvas=(MWRect){0,0,_logicalSize.width,_logicalSize.height};
        [self detachFromSnap];
        [self setNeedsLayout]; [self layoutIfNeeded];
        _gestureFrame=self.frame; [self focus];
        handle.dragging=YES;
        _model.resizeMode=free ? MWResizeFree : MWResizeProportional;
        if(!free) {
            CGSize system=[self systemCanvasSize];
            _model.aspectRatio=system.width/system.height;
            _model.frame=MWBeginProportionalResize(MWFromCGRect(_gestureFrame),MWFromCGRect(_viewport),_model.aspectRatio,_workspaceSafeInsets.top);
            self.frame=MWToCGRect(_model.frame); _gestureFrame=self.frame;
        }
        [gesture setTranslation:CGPointZero inView:self.superview]; delta=CGPointZero;
        MWLog(@"window.resize_begin",@{@"bundle":_application.bundleIdentifier,@"mode":free ? @"free" : @"proportional",@"corner":@(handle.corner)});
    }
    MWRect usable=MWProportionalViewport(MWFromCGRect(_viewport),_workspaceSafeInsets.top);
    _model.frame=free ? MWResizeFreeCornerRect(MWFromCGRect(_gestureFrame),delta.x,delta.y,MWFromCGRect(_viewport),handle.corner==MWResizeBottomLeft) :
        MWResizeAspectCornerRect(MWFromCGRect(_gestureFrame),delta.x,delta.y,usable,_model.aspectRatio,handle.corner==MWResizeTopLeft);
    self.frame=MWToCGRect(_model.frame);
    if(gesture.state==UIGestureRecognizerStateEnded || gesture.state==UIGestureRecognizerStateCancelled || gesture.state==UIGestureRecognizerStateFailed) {
        BOOL cancelled=gesture.state!=UIGestureRecognizerStateEnded;
        if(cancelled) { _model=_gestureModel; _canvasState=_gestureCanvasState; self.frame=MWToCGRect(_model.frame); }
        _resizing=NO; handle.dragging=NO;
        [self commitSceneGeometry]; if(!cancelled) [self geometryChanged];
        _resizeActivated=NO;
        MWLog(@"window.resize_finished",@{@"bundle":_application.bundleIdentifier,@"mode":free ? @"free" : @"system_proportional",@"corner":@(handle.corner),@"duration":@(CACurrentMediaTime()-_resizeStartedAt),@"sceneUpdates":@(_resizeSceneUpdates),@"cancelled":@(cancelled)});
        if(self.stateHandler) self.stateHandler();
    }
}
- (void)detachFromSnap {
    if(_model.snapTarget==MWSnapNone) return;
    // Snapped chrome has no extra top spacer. Free-window title safety is
    // applied on the following layout without changing the snap's outer size.
    _model.snapTarget=MWSnapNone; _model.frame=MWFromCGRect(self.frame);
    [self setNeedsLayout]; [self layoutIfNeeded];
}
- (void)focus { if(self.activateHandler) self.activateHandler(); }
- (void)prepareKeyboardFocusForTouchInView:(UIView *)view {
    (void)view;
    if(_hostHidden || self.hidden || _model.state!=MWWindowVisible) return;
    [self focus];
    [_session requestKeyboardFocusInWindow:self.window];
}
- (NSString *)touchRegionForView:(UIView *)view {
    if(!view) return @"none";
    if(self.isParked && [view isDescendantOfView:_parkedShield]) return @"parked_restore";
    if([view isDescendantOfView:_resize]) return @"bottom_right_aspect";
    if([view isDescendantOfView:_freeResize]) return @"top_right_free";
    if([view isDescendantOfView:_aspectTopLeft]) return @"top_left_aspect";
    if([view isDescendantOfView:_freeBottomLeft]) return @"bottom_left_free";
    if([view isDescendantOfView:_bar]) return @"title";
    if(_guestView && [view isDescendantOfView:_guestHost]) return @"guest_surface";
    if([view isDescendantOfView:_content]) return @"content_chrome";
    if([view isDescendantOfView:self]) return @"window_chrome";
    return @"outside_window";
}
- (void)recordTouchStartInView:(UIView *)view {
    NSString *region=[self touchRegionForView:view];
    if([region isEqual:@"guest_surface"]) _deliveredTouchStarts++;
    MWDiagnostics *diagnostics=MWDiagnostics.shared;
    if(!diagnostics.keyboardCaptureActive) return;
    if(_touchCapture!=diagnostics.keyboardCaptureGeneration) { _touchCapture=diagnostics.keyboardCaptureGeneration; _touchRecords=0; }
    if(_touchRecords>=40) return;
    _touchRecords++;
    MWLog(@"input.window_touch",@{@"bundle":self.application.bundleIdentifier,@"capture":@(_touchCapture),@"region":region,
        @"hitClass":view ? NSStringFromClass(view.class) : @"none",@"ordinal":@(_touchRecords)});
}
- (NSArray *)bottomHitProbes {
    if(!self.window || self.hidden || _hostHidden) return @[];
    NSMutableArray *probes=[NSMutableArray array];
    CGRect content=[self renderedGuestRectInWindow];
    // Synthetic host-window queries, never injected touches. Query only the
    // visible guest footer; do not walk or read guest text/control contents.
    for(NSNumber *fraction in @[@0.2,@0.5,@0.8]) for(NSNumber *distance in @[@12,@32]) {
        CGPoint point=CGPointMake(content.origin.x+content.size.width*fraction.doubleValue,
            CGRectGetMaxY(content)-MIN(distance.doubleValue,content.size.height/2));
        UIView *hit=[self.window hitTest:point withEvent:nil];
        [probes addObject:@{@"xFraction":fraction,@"fromBottom":distance,@"region":[self touchRegionForView:hit],
            @"hitClass":hit ? NSStringFromClass(hit.class) : @"none"}];
    }
    return probes;
}
- (NSDictionary *)inputDiagnosticSnapshotWithCapabilities:(BOOL)capabilities {
    return @{@"bundle":self.application.bundleIdentifier,@"state":@(_model.state),@"selected":@(self.active),
        @"compatibleCanvas":@(_compatibleCanvas),
        @"parked":@(self.isParked),
        @"snapTarget":@(_model.snapTarget),@"titleOriginY":@(_bar.frame.origin.y),
        @"attached":@(self.window!=nil),@"hidden":@(self.hidden),@"hostHidden":@(_hostHidden),
        @"deliveredTouchStarts":@(_deliveredTouchStarts),@"geometry":[_guestHost geometrySnapshot],
        @"contentFrame":MWRectFields(_content.frame),@"railFrame":MWRectFields(_inputRail.frame),
        @"cornerFrames":@[MWRectFields(_aspectTopLeft.frame),MWRectFields(_freeResize.frame),MWRectFields(_freeBottomLeft.frame),MWRectFields(_resize.frame)],
        @"railVisible":@(!_resize.hidden),@"railOverlapsContent":@(!_resize.hidden && CGRectIntersectsRect(_inputRail.frame,_content.frame)),
        @"renderedInWindow":MWRectFields([self renderedGuestRectInWindow]),
        @"bottomHitProbes":[self bottomHitProbes],@"probeScope":@"host_window_query_not_remote_delivery",
        @"session":_session ? [_session inputDiagnosticSnapshotWithCapabilities:capabilities] : @{}};
}
- (void)toggleMaximize {
    [self unpark];
    [self cancelInteractions];
    if(!MWWindowToggleMaximize(&_model,MWFromCGRect(_viewport))) return;
    [self focus];
    [UIView animateWithDuration:MWPreferences.shared.reduceMotion ? 0 : 0.22 animations:^{self.frame=MWToCGRect(self->_model.frame); [self layoutIfNeeded];}];
    [self updateStatus:nil]; [self commitSceneGeometry]; [self geometryChanged];
    MWLog(@"window.fullscreen",@{@"bundle":_application.bundleIdentifier,@"enabled":@(_model.maximized)});
    if(self.stateHandler) self.stateHandler();
}
- (void)geometryChanged {
    [self layoutIfNeeded];
    MWLog(@"window.geometry_committed",@{@"bundle":_application.bundleIdentifier,@"width":@(_model.frame.width),@"height":@(_model.frame.height),@"contentAspect":@(_model.aspectRatio),@"maximized":@(_model.maximized),@"mode":@(_model.resizeMode),@"snap":@(_model.snapTarget)});
    [self logContentGeometry:@"gesture_finished"];
    if(self.geometryHandler) self.geometryHandler(MWToCGRect(_model.maximized ? _model.restoreFrame : _model.frame));
}
- (void)applyViewport:(CGRect)viewport orientation:(UIInterfaceOrientation)orientation safeInsets:(UIEdgeInsets)insets {
    if(CGRectEqualToRect(_viewport,viewport) && _workspaceOrientation==orientation && UIEdgeInsetsEqualToEdgeInsets(_workspaceSafeInsets,insets)) return;
    [self cancelInteractions];
    _workspaceOrientation=orientation; _workspaceSafeInsets=insets;
    _viewport=viewport;
    [self updateGuestOrientationGeometry];
    if(self.isParked) {
        MWWindowReflow(&_parking.saved,MWFromCGRect(viewport));
        [self setNeedsLayout]; return;
    }
    MWWindowReflow(&_model,MWFromCGRect(viewport)); self.frame=MWToCGRect(_model.frame);
    [self setNeedsLayout];
}
- (void)cancelInteractions {
    if(!_dragging && !_resizing) return;
    MWWindowState state=_model.state;
    _model=_gestureModel; _model.state=state; _canvasState=_gestureCanvasState;
    _dragging=NO; _resizing=NO; _resizeActivated=NO; _geometryGeneration++; _geometryUpdatePending=NO;
    _freeResize.dragging=NO; _resize.dragging=NO; _aspectTopLeft.dragging=NO; _freeBottomLeft.dragging=NO;
    [self updateSnapCandidate:MWSnapNone]; self.frame=MWToCGRect(_model.frame);
    [self commitSceneGeometry];
    MWTrace(@"window.gesture_cancelled",@{@"bundle":_application.bundleIdentifier});
}
- (void)setInitialResizeMode:(MWResizeMode)mode {
    if(_session) return;
    _model.resizeMode=mode;
    _canvasState=(MWGuestCanvasState){0};
    CGSize system=[self systemCanvasSize];
    _model.aspectRatio=system.width/system.height;
}
- (void)setInitialCompatibleCanvas:(BOOL)enabled {
    if(_session) return;
    _compatibleCanvas=enabled; [self setNeedsLayout];
}
- (void)setInitialModel:(MWWindowModel)model {
    if(_session) return;
    _model=model; _model.state=MWWindowLoading; self.frame=MWToCGRect(model.frame);
    _canvasState=(MWGuestCanvasState){0};
    [self updateStatus:nil]; [self setNeedsLayout];
}
- (void)setInitiallyParked:(BOOL)parked { if(!_session) _parkWhenReady=parked; }
- (BOOL)isParked { return _parking.parked && _model.state==MWWindowParked; }
- (CGFloat)parkedContentRatio { return _parkedLogicalSize.width/MAX(1,_parkedLogicalSize.height); }
- (MWWindowModel)restorableModel { return self.isParked ? _parking.saved : _model; }
- (void)park {
    [self cancelInteractions]; [self layoutIfNeeded];
    if(!MWWindowPark(&_model,&_parking)) return;
    _parkedLogicalSize=_logicalSize; self.active=NO;
    _geometryUpdatePending=NO; _geometryDisplayLink.paused=YES;
    [self updateStatus:nil]; [self setNeedsLayout];
    MWLog(@"window.parked",@{@"bundle":_application.bundleIdentifier,@"width":@(_parking.saved.frame.width),
        @"height":@(_parking.saved.frame.height),@"mode":@(_parking.saved.resizeMode)});
}
- (void)placeParkedInFrame:(CGRect)frame {
    if(!self.isParked) return;
    if(!CGRectEqualToRect(self.frame,frame)) self.frame=frame;
    [self setNeedsLayout];
}
- (void)unpark {
    if(!MWWindowUnpark(&_model,&_parking,MWFromCGRect(_viewport))) return;
    self.frame=MWToCGRect(_model.frame); [self updateStatus:nil]; [self commitSceneGeometry];
    MWLog(@"window.unparked",@{@"bundle":_application.bundleIdentifier,@"width":@(_model.frame.width),@"height":@(_model.frame.height)});
}
- (CGSize)systemCanvasSize {
    UIScreen *screen=self.window.windowScene.screen ?: UIScreen.mainScreen;
    CGSize reference=screen.fixedCoordinateSpace.bounds.size;
    UIInterfaceOrientation orientation=[self guestOrientation];
    BOOL landscape=UIInterfaceOrientationIsLandscape(orientation);
    if(orientation==UIInterfaceOrientationUnknown) landscape=screen.bounds.size.width>screen.bounds.size.height;
    MWRect canvas=MWSystemCanvas(reference.width,reference.height,landscape);
    return CGSizeMake(canvas.width,canvas.height);
}
- (UIInterfaceOrientation)guestOrientation {
    UIInterfaceOrientation workspace=_workspaceOrientation ?: self.window.windowScene.interfaceOrientation;
    return _session ? [_session orientationForWorkspace:workspace] : workspace;
}
- (void)updateGuestOrientationGeometry {
    UIInterfaceOrientation orientation=[self guestOrientation];
    if(orientation==UIInterfaceOrientationUnknown || orientation==_layoutGuestOrientation) return;
    BOOL switchedAxes=_layoutGuestOrientation && UIInterfaceOrientationIsLandscape(_layoutGuestOrientation)!=UIInterfaceOrientationIsLandscape(orientation);
    _layoutGuestOrientation=orientation;
    if(self.isParked && switchedAxes) _parkedLogicalSize=CGSizeMake(_parkedLogicalSize.height,_parkedLogicalSize.width);
    if(_model.resizeMode==MWResizeProportional) {
        CGSize system=[self systemCanvasSize]; _model.aspectRatio=system.width/system.height;
        if(self.isParked) _parking.saved.aspectRatio=_model.aspectRatio;
        else if(_viewport.size.width>0 && _viewport.size.height>0) {
            MWWindowReflow(&_model,MWFromCGRect(_viewport)); self.frame=MWToCGRect(_model.frame);
        }
    }
}
- (void)logContentGeometry:(NSString *)reason {
    MWLog(@"window.content_geometry",@{@"bundle":_application.bundleIdentifier,@"reason":reason,
        @"compatibleCanvas":@(_compatibleCanvas),@"snapTarget":@(_model.snapTarget),
        @"titleOriginY":@(_bar.frame.origin.y),@"geometry":[_guestHost geometrySnapshot]});
}
- (void)requestClose { if(self.closeHandler) self.closeHandler(); }
- (void)requestPark { if(self.parkHandler) self.parkHandler(); }
- (void)requestRestore { if(self.restoreHandler) self.restoreHandler(); }
- (void)requestMinimize { if(self.minimizeHandler) self.minimizeHandler(); }
- (void)minimize {
    [self unpark];
    [self cancelInteractions];
    if(!MWWindowApply(&_model,MWEventMinimize)) return;
    MWLog(@"window.minimize",@{@"bundle":_application.bundleIdentifier});
    self.hidden=YES; [self applyExecutionPolicy];
}
- (void)restore {
    if(self.isParked) { [self unpark]; return; }
    if(!MWWindowApply(&_model,MWEventRestore)) return;
    MWLog(@"window.restore",@{@"bundle":_application.bundleIdentifier});
    self.hidden=NO; [self applyExecutionPolicy]; [self updateStatus:nil];
}
- (void)close {
    if(!MWWindowApply(&_model,MWEventClose)) { [_session close]; return; }
    _snapGeneration++; _geometryGeneration++;
    [_geometryDisplayLink invalidate]; _geometryDisplayLink=nil;
    _dragging=NO; _resizing=NO;
    if(self.snapPreviewHandler) self.snapPreviewHandler(CGRectZero,NO);
    _guestHost.guestView=nil; [_guestView removeFromSuperview]; _guestView=nil; [_session close]; [self removeFromSuperview];
}
- (void)closeAfterUserRequest:(void (^)(NSError *))completion {
    if(_userClosePending) return;
    if(!_userCloseStatus && !MWWindowApply(&_model,MWEventClose)) { completion(nil); return; }
    _userClosePending=YES; _userCloseStatus=@"正在结束应用…\n完成后再从主屏幕打开";
    self.hidden=NO; [self updateStatus:nil];
    _snapGeneration++; _geometryGeneration++;
    [_geometryDisplayLink invalidate]; _geometryDisplayLink=nil;
    _dragging=NO; _resizing=NO;
    if(self.snapPreviewHandler) self.snapPreviewHandler(CGRectZero,NO);
    _guestHost.guestView=nil; [_guestView removeFromSuperview]; _guestView=nil;
    __weak typeof(self) weakSelf=self;
    _session.closeProgressHandler=^{
        MWWindowView *view=weakSelf;
        if(!view || !view->_userClosePending) return;
        view->_userCloseStatus=@"系统仍在处理结束请求\n可从系统多任务界面结束此应用";
        [view updateStatus:nil]; if(view.stateHandler) view.stateHandler();
    };
    void (^finished)(NSError *)=^(NSError *error) {
        MWWindowView *view=weakSelf;
        if(view) {
            view->_userClosePending=NO;
            view->_userCloseStatus=error ? [NSString stringWithFormat:@"结束未完成：%@\n可点关闭重试",error.localizedDescription] : nil;
            if(error) [view updateStatus:nil]; else [view removeFromSuperview];
            if(view.stateHandler) view.stateHandler();
        }
        completion(error);
    };
    if(_session) [_session closeAfterUserRequest:finished]; else finished(nil);
}
- (NSString *)userCloseStatus { return _userCloseStatus; }
- (BOOL)userClosePending { return _userClosePending; }
- (void)releaseForOriginalApplication:(void (^)(NSError *))completion {
    NSError *issue=[_session originalApplicationHandoffIssue];
    if(issue) { completion(issue); return; }
    [self cancelInteractions];
    if(!MWWindowApply(&_model,MWEventClose)) { completion([NSError errorWithDomain:@"HaruGalaxy" code:63 userInfo:@{NSLocalizedDescriptionKey:@"该窗口已结束。"}]); return; }
    _snapGeneration++; _geometryGeneration++;
    [_geometryDisplayLink invalidate]; _geometryDisplayLink=nil;
    if(self.snapPreviewHandler) self.snapPreviewHandler(CGRectZero,NO);
    _guestHost.guestView=nil; [_guestView removeFromSuperview]; _guestView=nil;
    [self removeFromSuperview];
    if(_session) [_session closeForOriginalApplication:completion]; else completion(nil);
}
- (void)setHostVisible:(BOOL)visible {
    if(!visible) [self cancelInteractions];
    _hostHidden=!visible;
    [self applyExecutionPolicy];
}
- (void)applyExecutionPolicy {
    MWGuestExecution policy=MWGuestExecutionForState(_model.state,!_hostHidden,MWPreferences.shared.keepMinimizedAlive);
    [_session setVisible:policy.presented keepAlive:policy.keepAlive];
}
- (void)dealloc { [_geometryDisplayLink invalidate]; [_session close]; }
@end
