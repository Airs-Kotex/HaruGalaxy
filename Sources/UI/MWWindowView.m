// SPDX-License-Identifier: Apache-2.0
#import "MWWindowView.h"
#import "MWPreferences.h"
#import "MWGuestContentView.h"
#import "../Diagnostics/MWDiagnostics.h"

static MWRect MWFromCGRect(CGRect r) { return (MWRect){r.origin.x,r.origin.y,r.size.width,r.size.height}; }
static CGRect MWToCGRect(MWRect r) { return CGRectMake(r.x,r.y,r.width,r.height); }

@interface MWWindowView () <UIGestureRecognizerDelegate>
@end
@implementation MWWindowView {
    UIView *_surface, *_content;
    UIVisualEffectView *_bar;
    UILabel *_title, *_message;
    UIButton *_minimize, *_maximize, *_retry, *_resize, *_freeResize;
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
        _surface=[UIView new]; _surface.backgroundColor=UIColor.secondarySystemBackgroundColor;
        _surface.layer.cornerRadius=18; _surface.layer.cornerCurve=kCACornerCurveContinuous;
        _surface.clipsToBounds=YES; _surface.layer.borderWidth=1;
        [self addSubview:_surface];
        _content=[UIView new]; _content.clipsToBounds=YES; [_surface addSubview:_content];
        _guestHost=[MWGuestContentView new]; [_content addSubview:_guestHost];
        _bar=[[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemChromeMaterial]];
        [_surface addSubview:_bar];
        _title=[UILabel new]; _title.text=application.name;
        _title.font=[UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
        _title.lineBreakMode=NSLineBreakByTruncatingTail;
        [_bar.contentView addSubview:_title];
        [self button:@"xmark" label:@"关闭小窗" color:UIColor.systemRedColor action:@selector(requestClose) x:0];
        _minimize=[self button:@"minus" label:@"最小化" color:UIColor.systemOrangeColor action:@selector(requestMinimize) x:44];
        _maximize=[self button:@"arrow.up.left.and.arrow.down.right" label:@"最大化或恢复" color:UIColor.systemGreenColor action:@selector(toggleMaximize) x:88];
        _spinner=[[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
        [_content addSubview:_spinner];
        _message=[UILabel new]; _message.numberOfLines=0; _message.textAlignment=NSTextAlignmentCenter;
        _message.font=[UIFont systemFontOfSize:14]; _message.textColor=UIColor.secondaryLabelColor;
        [_content addSubview:_message];
        _retry=[UIButton buttonWithType:UIButtonTypeSystem]; [_retry setTitle:@"重试打开" forState:UIControlStateNormal];
        [_retry addTarget:self action:@selector(retry) forControlEvents:UIControlEventTouchUpInside];
        [_content addSubview:_retry];
        _resize=[UIButton buttonWithType:UIButtonTypeSystem];
        [_resize setImage:[UIImage systemImageNamed:@"arrow.up.left.and.arrow.down.right"] forState:UIControlStateNormal];
        _resize.accessibilityLabel=@"拖动以调整窗口大小";
        _resize.backgroundColor=[UIColor.tertiarySystemBackgroundColor colorWithAlphaComponent:0.92];
        _resize.layer.cornerRadius=12; [_surface addSubview:_resize];
        _resize.accessibilityLabel=@"右下角：等比缩放";
        _freeResize=[UIButton buttonWithType:UIButtonTypeSystem];
        [_freeResize setImage:[UIImage systemImageNamed:@"arrow.up.right.and.arrow.down.left"] forState:UIControlStateNormal];
        _freeResize.accessibilityLabel=@"左下角：自由缩放";
        _freeResize.backgroundColor=_resize.backgroundColor; _freeResize.layer.cornerRadius=12;
        _freeResize.tintColor=UIColor.systemOrangeColor; [_surface addSubview:_freeResize];
        [self addResizeCaption:@"自由" toButton:_freeResize]; [self addResizeCaption:@"等比" toButton:_resize];
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
    button.frame=CGRectMake(x,0,44,48); button.tintColor=color;
    [button setImage:[UIImage systemImageNamed:symbol withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:13 weight:UIImageSymbolWeightBold]] forState:UIControlStateNormal];
    button.accessibilityLabel=label; [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    [_bar.contentView addSubview:button]; return button;
}
- (void)addResizeCaption:(NSString *)caption toButton:(UIButton *)button {
    UILabel *label=[[UILabel alloc] initWithFrame:CGRectMake(0,2,44,14)];
    label.text=caption; label.font=[UIFont systemFontOfSize:10 weight:UIFontWeightSemibold];
    label.textAlignment=NSTextAlignmentCenter; label.textColor=button.tintColor; label.userInteractionEnabled=NO;
    [button addSubview:label]; button.imageEdgeInsets=UIEdgeInsetsMake(12,10,2,10);
}
- (void)layoutSubviews {
    [super layoutSubviews];
    _surface.frame=self.bounds;
    CGFloat titleInset=0;
    if(_model.snapTarget==MWSnapTop && !_model.maximized)
        titleInset=MAX(0,self.window.safeAreaInsets.top-self.frame.origin.y);
    CGFloat header=_model.maximized ? 0 : MWTitleHeight+titleInset;
    _surface.layer.cornerRadius=_model.maximized ? 0 : 18;
    _surface.layer.borderWidth=_model.maximized ? 0 : 1;
    _bar.hidden=_model.maximized;
    CGFloat leading=MAX(0,self.window.safeAreaInsets.left-self.frame.origin.x);
    CGFloat trailing=MAX(0,CGRectGetMaxX(self.frame)-(CGRectGetMaxX(_viewport)-self.window.safeAreaInsets.right));
    _bar.frame=CGRectMake(leading,titleInset,MAX(1,self.bounds.size.width-leading-trailing),MWTitleHeight);
    _title.frame=CGRectMake(140,0,MAX(0,_bar.bounds.size.width-152),MWTitleHeight);
    _content.frame=CGRectMake(0,header,self.bounds.size.width,MAX(1,self.bounds.size.height-header));
    if(_model.maximized || _model.resizeMode==MWResizeFree) _logicalSize=_content.bounds.size;
    else _logicalSize=_proportionalSize;
    _guestHost.frame=_content.bounds;
    _guestHost.logicalSize=_logicalSize;
    [_guestHost layoutIfNeeded];
    _spinner.center=CGPointMake(CGRectGetMidX(_content.bounds),CGRectGetMidY(_content.bounds)-32);
    _message.frame=CGRectMake(16,MAX(12,CGRectGetMidY(_content.bounds)-16),MAX(1,_content.bounds.size.width-32),72);
    _retry.frame=CGRectMake(20,MIN(_content.bounds.size.height-48,CGRectGetMaxY(_message.frame)),MAX(1,_content.bounds.size.width-40),44);
    _resize.frame=CGRectMake(self.bounds.size.width-44,self.bounds.size.height-44,44,44);
    _freeResize.frame=CGRectMake(0,self.bounds.size.height-44,44,44);
    _resize.hidden=_freeResize.hidden=_model.maximized || _model.state!=MWWindowVisible;
    self.layer.shadowPath=[UIBezierPath bezierPathWithRoundedRect:self.bounds cornerRadius:_model.maximized ? 0 : 18].CGPath;
    UIInterfaceOrientation orientation=self.window.windowScene.interfaceOrientation;
    if(!CGSizeEqualToSize(_lastSize,_logicalSize) || _lastOrientation!=orientation) {
        if(_resizing) [self scheduleSceneGeometry]; else [self submitSceneGeometry];
    }
}
- (void)scheduleSceneGeometry {
    if(_geometryUpdatePending) return;
    _geometryUpdatePending=YES; NSUInteger generation=++_geometryGeneration;
    __weak typeof(self) weakSelf=self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(0.05*NSEC_PER_SEC)),dispatch_get_main_queue(),^{
        MWWindowView *view=weakSelf;
        if(!view || view->_geometryGeneration!=generation || view->_model.state==MWWindowClosed) return;
        view->_geometryUpdatePending=NO; [view submitSceneGeometry];
    });
}
- (void)submitSceneGeometry {
    _lastSize=_logicalSize; _lastOrientation=self.window.windowScene.interfaceOrientation;
    [_session updateSize:_logicalSize orientation:_lastOrientation];
}
- (void)commitSceneGeometry {
    _geometryGeneration++; _geometryUpdatePending=NO;
    [self setNeedsLayout]; [self layoutIfNeeded]; [self submitSceneGeometry];
}
- (void)start {
    [self layoutIfNeeded];
    _session=[[MWSceneSession alloc] initWithBundleIdentifier:_application.bundleIdentifier];
    [_session setVisible:!_hostHidden];
    __weak typeof(self) weakSelf=self;
    _session.failureHandler=^(NSError *error) { [weakSelf failed:error]; };
    [_session updateSize:_logicalSize orientation:self.window.windowScene.interfaceOrientation];
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
}
- (void)setActive:(BOOL)active {
    _active=active;
    UIColor *color=active ? UIColor.systemTealColor : UIColor.separatorColor;
    _surface.layer.borderColor=[color resolvedColorWithTraitCollection:self.traitCollection].CGColor;
    self.layer.shadowOpacity=active ? 0.23 : 0.12;
}
- (void)traitCollectionDidChange:(UITraitCollection *)previous {
    [super traitCollectionDidChange:previous]; [self setActive:self.active];
}
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)recognizer shouldReceiveTouch:(UITouch *)touch {
    if(recognizer.view==_resize || recognizer.view==_freeResize) return YES;
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
        CGRect moveBounds=_viewport;
        CGFloat safeTop=self.window.safeAreaInsets.top;
        moveBounds.origin.y+=safeTop; moveBounds.size.height=MAX(1,moveBounds.size.height-safeTop);
        _model.frame=_model.resizeMode==MWResizeProportional ? MWFitAspectRect(MWFromCGRect(frame),MWFromCGRect(moveBounds),_model.aspectRatio) : MWConstrainRect(MWFromCGRect(frame),MWFromCGRect(moveBounds));
        self.frame=MWToCGRect(_model.frame);
        CGPoint location=[gesture locationInView:self.superview];
        [self updateSnapCandidate:_model.resizeMode==MWResizeFree ? MWSnapTargetAtPoint(MWFromCGRect(_viewport),location.x,location.y) : MWSnapNone];
    }
    if(gesture.state==UIGestureRecognizerStateEnded || gesture.state==UIGestureRecognizerStateCancelled || gesture.state==UIGestureRecognizerStateFailed) {
        if(!_dragging) return;
        BOOL cancelled=gesture.state!=UIGestureRecognizerStateEnded;
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
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(0.2*NSEC_PER_SEC)),dispatch_get_main_queue(),^{
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
        _model.resizeMode=free ? MWResizeFree : MWResizeProportional;
        if(!free) {
            _proportionalSize=_logicalSize;
            _model.aspectRatio=self.bounds.size.width/MAX(1,self.bounds.size.height-MWTitleHeight);
        }
        MWLog(@"window.resize_begin",@{@"bundle":_application.bundleIdentifier,@"mode":free ? @"free" : @"proportional"});
    }
    if(!_resizing) return;
    CGPoint delta=[gesture translationInView:self.superview];
    _model.frame=free ? MWResizeFreeRect(MWFromCGRect(_gestureFrame),delta.x,delta.y,MWFromCGRect(_viewport),YES) :
        MWResizeAspectRect(MWFromCGRect(_gestureFrame),delta.x,delta.y,MWFromCGRect(_viewport),_model.aspectRatio);
    self.frame=MWToCGRect(_model.frame);
    if(gesture.state==UIGestureRecognizerStateEnded || gesture.state==UIGestureRecognizerStateCancelled || gesture.state==UIGestureRecognizerStateFailed) {
        BOOL cancelled=gesture.state!=UIGestureRecognizerStateEnded;
        if(cancelled) { _model=_gestureModel; _proportionalSize=_gestureLogicalSize; self.frame=MWToCGRect(_model.frame); }
        _resizing=NO; [self commitSceneGeometry]; if(!cancelled) [self geometryChanged];
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
    _viewport=viewport; MWWindowReflow(&_model,MWFromCGRect(viewport)); self.frame=MWToCGRect(_model.frame);
    [self setNeedsLayout];
}
- (void)cancelInteractions {
    if(!_dragging && !_resizing) return;
    MWWindowState state=_model.state;
    _model=_gestureModel; _model.state=state; _proportionalSize=_gestureLogicalSize;
    _dragging=NO; _resizing=NO; _geometryGeneration++; _geometryUpdatePending=NO;
    [self updateSnapCandidate:MWSnapNone]; self.frame=MWToCGRect(_model.frame);
    [self commitSceneGeometry];
    MWTrace(@"window.gesture_cancelled",@{@"bundle":_application.bundleIdentifier});
}
- (void)setInitialResizeMode:(MWResizeMode)mode {
    if(_session) return;
    _model.resizeMode=mode;
    _proportionalSize=CGSizeMake(MAX(1,self.bounds.size.width),MAX(1,self.bounds.size.height-MWTitleHeight));
    _model.aspectRatio=_proportionalSize.width/_proportionalSize.height;
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
    if(!MWWindowApply(&_model,MWEventClose)) return;
    _snapGeneration++; _geometryGeneration++;
    _dragging=NO; _resizing=NO;
    if(self.snapPreviewHandler) self.snapPreviewHandler(CGRectZero,NO);
    _guestHost.guestView=nil; [_guestView removeFromSuperview]; _guestView=nil; [_session close]; [self removeFromSuperview];
}
- (void)setHostVisible:(BOOL)visible {
    if(!visible) [self cancelInteractions];
    _hostHidden=!visible;
    [_session setVisible:visible && _model.state!=MWWindowMinimized];
}
- (void)dealloc { [_session close]; }
@end
