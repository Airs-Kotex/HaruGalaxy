// SPDX-License-Identifier: Apache-2.0
#import "MWWindowView.h"
#import "MWPreferences.h"
#import "MWGuestContentView.h"
#import "MWCornerHandle.h"
#import "MWGlassSurface.h"
#import "../Diagnostics/MWDiagnostics.h"

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
    UILabel *_title, *_message;
    UIButton *_minimize, *_maximize, *_retry;
    MWCornerHandle *_resize, *_freeResize;
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
    CGSize _proportionalSize, _restoreLogicalSize, _gestureLogicalSize;
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
}
@synthesize model=_model;

- (instancetype)initWithApplication:(MWApplication *)application frame:(CGRect)frame {
    if((self=[super initWithFrame:frame])) {
        _application=application; _model=MWWindowCreate(MWFromCGRect(frame));
        _logicalSize=UIScreen.mainScreen.bounds.size;
        _proportionalSize=_logicalSize;
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
        _title=[UILabel new]; _title.text=application.name;
        _title.font=[UIFont systemFontOfSize:12 weight:UIFontWeightSemibold];
        _title.lineBreakMode=NSLineBreakByTruncatingTail;
        [_bar.contentView addSubview:_title];
        [self button:@"xmark" label:@"关闭小窗" color:UIColor.systemRedColor action:@selector(requestClose) x:0];
        _minimize=[self button:@"minus" label:@"最小化" color:UIColor.systemOrangeColor action:@selector(requestMinimize) x:28];
        _maximize=[self button:@"arrow.up.left.and.arrow.down.right" label:@"最大化或恢复" color:UIColor.systemGreenColor action:@selector(toggleMaximize) x:56];
        _spinner=[[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
        [_content addSubview:_spinner];
        _message=[UILabel new]; _message.numberOfLines=0; _message.textAlignment=NSTextAlignmentCenter;
        _message.font=[UIFont systemFontOfSize:14]; _message.textColor=UIColor.secondaryLabelColor;
        [_content addSubview:_message];
        _retry=[UIButton buttonWithType:UIButtonTypeSystem]; [_retry setTitle:@"重试打开" forState:UIControlStateNormal];
        [_retry addTarget:self action:@selector(retry) forControlEvents:UIControlEventTouchUpInside];
        [_content addSubview:_retry];
        _resize=[[MWCornerHandle alloc] initAtTop:NO]; [_surface addSubview:_resize];
        _freeResize=[[MWCornerHandle alloc] initAtTop:YES]; [_surface addSubview:_freeResize];
        UIPanGestureRecognizer *drag=[[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(drag:)];
        drag.delegate=self; drag.maximumNumberOfTouches=1; [_bar addGestureRecognizer:drag];
        UITapGestureRecognizer *doubleTap=[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(toggleMaximize)];
        doubleTap.numberOfTapsRequired=2; doubleTap.delegate=self; [_bar addGestureRecognizer:doubleTap];
        UITapGestureRecognizer *focus=[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(focus)];
        focus.delegate=self; [focus requireGestureRecognizerToFail:doubleTap]; [_bar addGestureRecognizer:focus];
        UIPanGestureRecognizer *resize=[[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(resize:)];
        resize.maximumNumberOfTouches=1; resize.delegate=self;
        [_resize addGestureRecognizer:resize];
        UIPanGestureRecognizer *freeResize=[[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(resize:)];
        freeResize.maximumNumberOfTouches=1; freeResize.delegate=self; [_freeResize addGestureRecognizer:freeResize];
        [self setActive:YES]; [self updateStatus:nil];
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
    _surface.frame=self.bounds;
    CGFloat titleInset=0;
    if(_model.snapTarget==MWSnapTop && !_model.maximized)
        titleInset=MAX(0,self.window.safeAreaInsets.top-self.frame.origin.y);
    _surface.layer.cornerRadius=_model.maximized ? 0 : 18;
    _surface.layer.borderWidth=_model.maximized ? 0 : 1;
    _bar.hidden=_model.maximized;
    CGFloat leading=MAX(0,self.window.safeAreaInsets.left-self.frame.origin.x);
    CGFloat trailing=MAX(0,CGRectGetMaxX(self.frame)-(CGRectGetMaxX(_viewport)-self.window.safeAreaInsets.right));
    _bar.frame=CGRectMake(leading,titleInset,MAX(1,self.bounds.size.width-leading-trailing),MWTitleHeight);
    _title.frame=CGRectMake(92,0,MAX(0,_bar.bounds.size.width-96-MWCornerTouchSize),MWTitleHeight);
    _content.frame=MWToCGRect(MWWindowContentRect(MWFromCGRect(self.bounds),titleInset,_model.maximized));
    _inputRail.frame=MWToCGRect(MWWindowRailRect(MWFromCGRect(self.bounds),_model.maximized));
    _inputRail.hidden=_model.maximized || _model.state!=MWWindowVisible;
    if(_model.maximized || _model.resizeMode==MWResizeFree) _logicalSize=_content.bounds.size;
    else _logicalSize=_proportionalSize;
    _guestHost.frame=_content.bounds;
    _guestHost.logicalSize=_logicalSize;
    [_guestHost layoutIfNeeded];
    _spinner.center=CGPointMake(CGRectGetMidX(_content.bounds),CGRectGetMidY(_content.bounds)-32);
    _message.frame=CGRectMake(16,MAX(12,CGRectGetMidY(_content.bounds)-16),MAX(1,_content.bounds.size.width-32),72);
    _retry.frame=CGRectMake(20,MIN(_content.bounds.size.height-48,CGRectGetMaxY(_message.frame)),MAX(1,_content.bounds.size.width-40),44);
    _resize.frame=_inputRail.frame;
    _freeResize.frame=CGRectMake(CGRectGetMaxX(_bar.frame)-MWCornerTouchSize,titleInset,MWCornerTouchSize,MWCornerTouchSize);
    _resize.hidden=_freeResize.hidden=_model.maximized || _model.state!=MWWindowVisible;
    [_surface bringSubviewToFront:_inputRail];
    [_surface bringSubviewToFront:_resize]; [_surface bringSubviewToFront:_freeResize];
    if(!CGSizeEqualToSize(_shadowSize,self.bounds.size) || _shadowMaximized!=_model.maximized) {
        _shadowSize=self.bounds.size; _shadowMaximized=_model.maximized;
        self.layer.shadowPath=[UIBezierPath bezierPathWithRoundedRect:self.bounds cornerRadius:_model.maximized ? 0 : 18].CGPath;
    }
    UIInterfaceOrientation orientation=self.window.windowScene.interfaceOrientation;
    if(!CGSizeEqualToSize(_lastSize,_logicalSize) || _lastOrientation!=orientation ||
       !UIEdgeInsetsEqualToEdgeInsets(_lastSafeInsets,[self guestSafeInsets])) {
        if(_resizing || _dragging) [self scheduleSceneGeometry]; else [self submitSceneGeometry];
    }
}
- (CGRect)renderedGuestRectInWindow {
    MWContentTransform t=MWFitContent(_logicalSize.width,_logicalSize.height,_guestHost.bounds.size.width,_guestHost.bounds.size.height);
    return [_guestHost convertRect:CGRectMake(t.x,t.y,_logicalSize.width*t.scale,_logicalSize.height*t.scale) toView:self.window];
}
- (UIEdgeInsets)guestSafeInsets {
    if(!self.window) return UIEdgeInsetsZero;
    CGRect safe=UIEdgeInsetsInsetRect(self.window.bounds,self.window.safeAreaInsets);
    MWInsets insets=MWGuestSafeInsets(MWFromCGRect([self renderedGuestRectInWindow]),MWFromCGRect(safe),_logicalSize.width,_logicalSize.height);
    return UIEdgeInsetsMake(insets.top,insets.left,insets.bottom,insets.right);
}
- (void)safeAreaInsetsDidChange {
    [super safeAreaInsetsDidChange]; [self setNeedsLayout];
}
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    if(self.hidden || self.alpha<=0.01 || !self.userInteractionEnabled || ![self pointInside:point withEvent:event]) return nil;
    // Resolve only the local handles before descending into the remote scene.
    // Their rectangles sit entirely in host chrome; no cross-window substitution.
    MWCornerHandle *handles[]={_resize,_freeResize};
    for(NSUInteger i=0;i<2;i++) {
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
    UIInterfaceOrientation orientation=self.window.windowScene.interfaceOrientation;
    UIEdgeInsets insets=[self guestSafeInsets];
    if(CGSizeEqualToSize(_lastSize,_logicalSize) && _lastOrientation==orientation && UIEdgeInsetsEqualToEdgeInsets(_lastSafeInsets,insets)) return;
    _lastSize=_logicalSize; _lastOrientation=orientation; _lastSafeInsets=insets;
    if(_resizing) _resizeSceneUpdates++;
    [_session updateSize:_logicalSize orientation:_lastOrientation safeAreaInsets:insets];
}
- (void)commitSceneGeometry {
    _geometryGeneration++; _geometryUpdatePending=NO; _geometryDisplayLink.paused=YES;
    [self setNeedsLayout]; [self layoutIfNeeded]; [self submitSceneGeometry];
}
- (void)start {
    [self layoutIfNeeded];
    _session=[[MWSceneSession alloc] initWithBundleIdentifier:_application.bundleIdentifier];
    [_session setVisible:!_hostHidden];
    __weak typeof(self) weakSelf=self;
    _session.failureHandler=^(NSError *error) { [weakSelf failed:error]; };
    _session.inputRequestHandler=^{
        MWWindowView *view=weakSelf;
        // Guest notifications can be delayed or caused by autofocus. They may
        // refresh only the already-selected visible window, never steal input
        // from a different guest or the host's presented picker.
        if(view && view.active && !view->_hostHidden && !view.hidden && !view.window.rootViewController.presentedViewController)
            [view.session refreshKeyboardFocusInWindow:view.window];
    };
    [_session updateSize:_logicalSize orientation:self.window.windowScene.interfaceOrientation safeAreaInsets:[self guestSafeInsets]];
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
        if(view.stateHandler) view.stateHandler();
        if(view.active && !view->_hostHidden && !view.hidden && !view.window.rootViewController.presentedViewController)
            [view.session requestKeyboardFocusInWindow:view.window];
    }];
}
- (void)failed:(NSError *)error {
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
    BOOL loading=_model.state==MWWindowLoading;
    if(error.length) _failureMessage=[error copy];
    if(_model.state!=MWWindowFailed) _failureMessage=nil;
    _message.text=_model.state==MWWindowFailed ? (_failureMessage ?: @"小窗暂时不可用，请重试。") : @"正在打开应用…";
    _message.hidden=!loading && _model.state!=MWWindowFailed;
    _retry.hidden=_model.state!=MWWindowFailed;
    if(loading) [_spinner startAnimating]; else [_spinner stopAnimating];
    _minimize.enabled=_maximize.enabled=(_model.state==MWWindowVisible);
    _resize.hidden=_freeResize.hidden=_model.maximized || _model.state!=MWWindowVisible;
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
    if(recognizer.view==_resize || recognizer.view==_freeResize) return YES;
    // A pan beginning over title-bar buttons cancels the button's tap. Narrow
    // windows must still have a usable drag area when controls fill the bar.
    if(recognizer.view==_bar && [recognizer isKindOfClass:UIPanGestureRecognizer.class]) return YES;
    for(UIView *view=touch.view;view && view!=_bar;view=view.superview)
        if([view isKindOfClass:UIControl.class]) return NO;
    return YES;
}
- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gesture {
    (void)gesture;
    return !_dragging && !_resizing && _model.state!=MWWindowClosed && _model.state!=MWWindowMinimized;
}
- (void)drag:(UIPanGestureRecognizer *)gesture {
    if(_model.maximized || _model.state==MWWindowClosed || _model.state==MWWindowMinimized) return;
    if(gesture.state==UIGestureRecognizerStateBegan) {
        [self layoutIfNeeded];
        _dragging=YES; _gestureModel=_model; _gestureLogicalSize=_proportionalSize;
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
        if(cancelled) { _model=_gestureModel; _proportionalSize=_gestureLogicalSize; }
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
    BOOL free=gesture.view==_freeResize;
    if(gesture.state==UIGestureRecognizerStateBegan) {
        [self layoutIfNeeded];
        _gestureModel=_model; _gestureLogicalSize=_proportionalSize;
        [self detachFromSnap];
        [self setNeedsLayout]; [self layoutIfNeeded];
        _gestureFrame=self.frame; _resizing=YES; [self focus];
        _resizeStartedAt=CACurrentMediaTime(); _resizeSceneUpdates=0;
        _freeResize.dragging=free; _resize.dragging=!free;
        _model.resizeMode=free ? MWResizeFree : MWResizeProportional;
        if(!free) {
            _proportionalSize=[self systemCanvasSize];
            _model.aspectRatio=_proportionalSize.width/_proportionalSize.height;
            _model.frame=MWFitAspectRect(MWFromCGRect(_gestureFrame),MWFromCGRect(_viewport),_model.aspectRatio);
            self.frame=MWToCGRect(_model.frame); _gestureFrame=self.frame;
        }
        MWLog(@"window.resize_begin",@{@"bundle":_application.bundleIdentifier,@"mode":free ? @"free" : @"proportional"});
    }
    if(!_resizing) return;
    CGPoint delta=[gesture translationInView:self.superview];
    _model.frame=free ? MWResizeTopRightRect(MWFromCGRect(_gestureFrame),delta.x,delta.y,MWFromCGRect(_viewport)) :
        MWResizeAspectRect(MWFromCGRect(_gestureFrame),delta.x,delta.y,MWFromCGRect(_viewport),_model.aspectRatio);
    self.frame=MWToCGRect(_model.frame);
    if(gesture.state==UIGestureRecognizerStateEnded || gesture.state==UIGestureRecognizerStateCancelled || gesture.state==UIGestureRecognizerStateFailed) {
        BOOL cancelled=gesture.state!=UIGestureRecognizerStateEnded;
        if(cancelled) { _model=_gestureModel; _proportionalSize=_gestureLogicalSize; self.frame=MWToCGRect(_model.frame); }
        _resizing=NO; _freeResize.dragging=NO; _resize.dragging=NO;
        [self commitSceneGeometry]; if(!cancelled) [self geometryChanged];
        MWLog(@"window.resize_finished",@{@"bundle":_application.bundleIdentifier,@"mode":free ? @"free" : @"system_proportional",@"duration":@(CACurrentMediaTime()-_resizeStartedAt),@"sceneUpdates":@(_resizeSceneUpdates),@"cancelled":@(cancelled)});
        if(self.stateHandler) self.stateHandler();
    }
}
- (void)detachFromSnap {
    if(_model.snapTarget==MWSnapNone) return;
    // Remove only the extra top chrome, translating the frame by the same
    // amount. The guest origin, visible dimensions and title stay in place.
    MWRect frame=MWUnpinFrame(MWFromCGRect(self.frame),MAX(0,_content.frame.origin.y-MWTitleHeight));
    _model.snapTarget=MWSnapNone; _model.frame=frame; self.frame=MWToCGRect(frame);
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
    if([view isDescendantOfView:_resize]) return @"resize_rail";
    if([view isDescendantOfView:_freeResize]) return @"free_resize";
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
        @"attached":@(self.window!=nil),@"hidden":@(self.hidden),@"hostHidden":@(_hostHidden),
        @"deliveredTouchStarts":@(_deliveredTouchStarts),@"geometry":[_guestHost geometrySnapshot],
        @"contentFrame":MWRectFields(_content.frame),@"railFrame":MWRectFields(_resize.frame),
        @"railVisible":@(!_resize.hidden),@"railOverlapsContent":@(!_resize.hidden && CGRectIntersectsRect(_resize.frame,_content.frame)),
        @"renderedInWindow":MWRectFields([self renderedGuestRectInWindow]),
        @"bottomHitProbes":[self bottomHitProbes],@"probeScope":@"host_window_query_not_remote_delivery",
        @"session":_session ? [_session inputDiagnosticSnapshotWithCapabilities:capabilities] : @{}};
}
- (void)toggleMaximize {
    [self cancelInteractions];
    BOOL wasMaximized=_model.maximized;
    if(!MWWindowToggleMaximize(&_model,MWFromCGRect(_viewport))) return;
    if(!wasMaximized) _restoreLogicalSize=_proportionalSize;
    else _proportionalSize=_restoreLogicalSize;
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
- (void)applyViewport:(CGRect)viewport {
    [self cancelInteractions];
    if(_model.resizeMode==MWResizeProportional) {
        _proportionalSize=[self systemCanvasSize]; _model.aspectRatio=_proportionalSize.width/_proportionalSize.height;
        if(_model.maximized) _restoreLogicalSize=_proportionalSize;
    }
    _viewport=viewport; MWWindowReflow(&_model,MWFromCGRect(viewport)); self.frame=MWToCGRect(_model.frame);
    [self setNeedsLayout];
}
- (void)cancelInteractions {
    if(!_dragging && !_resizing) return;
    MWWindowState state=_model.state;
    _model=_gestureModel; _model.state=state; _proportionalSize=_gestureLogicalSize;
    _dragging=NO; _resizing=NO; _geometryGeneration++; _geometryUpdatePending=NO;
    _freeResize.dragging=NO; _resize.dragging=NO;
    [self updateSnapCandidate:MWSnapNone]; self.frame=MWToCGRect(_model.frame);
    [self commitSceneGeometry];
    MWTrace(@"window.gesture_cancelled",@{@"bundle":_application.bundleIdentifier});
}
- (void)setInitialResizeMode:(MWResizeMode)mode {
    if(_session) return;
    _model.resizeMode=mode;
    _proportionalSize=[self systemCanvasSize];
    _model.aspectRatio=_proportionalSize.width/_proportionalSize.height;
}
- (CGSize)systemCanvasSize {
    UIScreen *screen=self.window.windowScene.screen ?: UIScreen.mainScreen;
    CGSize reference=screen.fixedCoordinateSpace.bounds.size;
    UIInterfaceOrientation orientation=self.window.windowScene.interfaceOrientation;
    BOOL landscape=UIInterfaceOrientationIsLandscape(orientation);
    if(orientation==UIInterfaceOrientationUnknown) landscape=screen.bounds.size.width>screen.bounds.size.height;
    MWRect canvas=MWSystemCanvas(reference.width,reference.height,landscape);
    return CGSizeMake(canvas.width,canvas.height);
}
- (void)logContentGeometry:(NSString *)reason {
    MWLog(@"window.content_geometry",@{@"bundle":_application.bundleIdentifier,@"reason":reason,@"geometry":[_guestHost geometrySnapshot]});
}
- (void)requestClose { if(self.closeHandler) self.closeHandler(); }
- (void)requestMinimize { if(self.minimizeHandler) self.minimizeHandler(); }
- (void)minimize {
    [self cancelInteractions];
    if(!MWWindowApply(&_model,MWEventMinimize)) return;
    MWLog(@"window.minimize",@{@"bundle":_application.bundleIdentifier});
    self.hidden=YES; [_session setVisible:NO];
}
- (void)restore {
    if(!MWWindowApply(&_model,MWEventRestore)) return;
    MWLog(@"window.restore",@{@"bundle":_application.bundleIdentifier});
    self.hidden=NO; [_session setVisible:!_hostHidden]; [self updateStatus:nil];
}
- (void)close {
    if(!MWWindowApply(&_model,MWEventClose)) { [_session close]; return; }
    _snapGeneration++; _geometryGeneration++;
    [_geometryDisplayLink invalidate]; _geometryDisplayLink=nil;
    _dragging=NO; _resizing=NO;
    if(self.snapPreviewHandler) self.snapPreviewHandler(CGRectZero,NO);
    _guestHost.guestView=nil; [_guestView removeFromSuperview]; _guestView=nil; [_session close]; [self removeFromSuperview];
}
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
    [_session setVisible:visible && _model.state!=MWWindowMinimized];
}
- (void)dealloc { [_geometryDisplayLink invalidate]; [_session close]; }
@end
