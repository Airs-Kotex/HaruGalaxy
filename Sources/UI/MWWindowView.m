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
    UIButton *_minimize, *_maximize, *_retry, *_resize;
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
        UIPanGestureRecognizer *drag=[[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(drag:)];
        drag.delegate=self; [_bar addGestureRecognizer:drag];
        UITapGestureRecognizer *doubleTap=[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(toggleMaximize)];
        doubleTap.numberOfTapsRequired=2; doubleTap.delegate=self; [_bar addGestureRecognizer:doubleTap];
        UIPanGestureRecognizer *resize=[[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(resize:)];
        [_resize addGestureRecognizer:resize];
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
- (void)layoutSubviews {
    [super layoutSubviews];
    _surface.frame=self.bounds;
    _bar.frame=CGRectMake(0,0,self.bounds.size.width,48);
    _title.frame=CGRectMake(140,0,MAX(0,self.bounds.size.width-152),48);
    _content.frame=CGRectMake(0,48,self.bounds.size.width,MAX(1,self.bounds.size.height-48));
    _guestHost.frame=_content.bounds;
    _guestHost.logicalSize=_logicalSize;
    [_guestHost layoutIfNeeded];
    _spinner.center=CGPointMake(CGRectGetMidX(_content.bounds),CGRectGetMidY(_content.bounds)-32);
    _message.frame=CGRectMake(16,MAX(12,CGRectGetMidY(_content.bounds)-16),MAX(1,_content.bounds.size.width-32),72);
    _retry.frame=CGRectMake(20,MIN(_content.bounds.size.height-48,CGRectGetMaxY(_message.frame)),MAX(1,_content.bounds.size.width-40),44);
    _resize.frame=CGRectMake(self.bounds.size.width-44,self.bounds.size.height-44,44,44);
    self.layer.shadowPath=[UIBezierPath bezierPathWithRoundedRect:self.bounds cornerRadius:18].CGPath;
    UIInterfaceOrientation orientation=self.window.windowScene.interfaceOrientation;
    if(!CGSizeEqualToSize(_lastSize,_logicalSize) || _lastOrientation!=orientation) {
        _lastSize=_logicalSize; _lastOrientation=orientation;
        [_session updateSize:_lastSize orientation:orientation];
    }
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
    _resize.hidden=_model.maximized;
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
    (void)recognizer;
    for(UIView *view=touch.view;view && view!=_bar;view=view.superview)
        if([view isKindOfClass:UIControl.class]) return NO;
    return YES;
}
- (void)drag:(UIPanGestureRecognizer *)gesture {
    if(_model.maximized) return;
    if(gesture.state==UIGestureRecognizerStateBegan) { _gestureFrame=self.frame; if(self.activateHandler) self.activateHandler(); }
    CGPoint delta=[gesture translationInView:self.superview];
    CGRect frame=_gestureFrame; frame.origin.x+=delta.x; frame.origin.y+=delta.y;
    _model.frame=MWFitAspectRect(MWFromCGRect(frame),MWFromCGRect(_viewport),_model.aspectRatio); self.frame=MWToCGRect(_model.frame);
    if(gesture.state==UIGestureRecognizerStateEnded || gesture.state==UIGestureRecognizerStateCancelled) [self geometryChanged];
}
- (void)resize:(UIPanGestureRecognizer *)gesture {
    if(_model.maximized) return;
    if(gesture.state==UIGestureRecognizerStateBegan) { _gestureFrame=self.frame; if(self.activateHandler) self.activateHandler(); }
    CGPoint delta=[gesture translationInView:self.superview];
    _model.frame=MWResizeAspectRect(MWFromCGRect(_gestureFrame),delta.x,delta.y,MWFromCGRect(_viewport),_model.aspectRatio);
    self.frame=MWToCGRect(_model.frame);
    if(gesture.state==UIGestureRecognizerStateEnded || gesture.state==UIGestureRecognizerStateCancelled) [self geometryChanged];
}
- (void)toggleMaximize {
    if(!MWWindowToggleMaximize(&_model,MWFromCGRect(_viewport))) return;
    if(self.activateHandler) self.activateHandler();
    [UIView animateWithDuration:MWPreferences.shared.reduceMotion ? 0 : 0.22 animations:^{self.frame=MWToCGRect(self->_model.frame); [self layoutIfNeeded];}];
    [self updateStatus:nil]; [self geometryChanged];
}
- (void)geometryChanged {
    [self layoutIfNeeded];
    MWLog(@"window.geometry_committed",@{@"bundle":_application.bundleIdentifier,@"width":@(_model.frame.width),@"height":@(_model.frame.height),@"contentAspect":@(_model.aspectRatio),@"maximized":@(_model.maximized)});
    [self logContentGeometry:@"gesture_finished"];
    if(self.geometryHandler) self.geometryHandler(MWToCGRect(_model.maximized ? _model.restoreFrame : _model.frame));
}
- (void)applyViewport:(CGRect)viewport {
    UIScreen *display=self.window.windowScene.screen ?: UIScreen.mainScreen;
    CGSize screen=display.fixedCoordinateSpace.bounds.size;
    UIInterfaceOrientation orientation=self.window.windowScene.interfaceOrientation;
    if(UIInterfaceOrientationIsLandscape(orientation) && screen.height>screen.width) screen=CGSizeMake(screen.height,screen.width);
    if(UIInterfaceOrientationIsPortrait(orientation) && screen.width>screen.height) screen=CGSizeMake(screen.height,screen.width);
    if(screen.width>0 && screen.height>0) { _logicalSize=screen; _model.aspectRatio=screen.width/screen.height; }
    _viewport=viewport; MWWindowReflow(&_model,MWFromCGRect(viewport)); self.frame=MWToCGRect(_model.frame);
}
- (void)logContentGeometry:(NSString *)reason {
    MWLog(@"window.content_geometry",@{@"bundle":_application.bundleIdentifier,@"reason":reason,@"geometry":[_guestHost geometrySnapshot]});
}
- (void)requestClose { if(self.closeHandler) self.closeHandler(); }
- (void)requestMinimize { if(self.minimizeHandler) self.minimizeHandler(); }
- (void)minimize {
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
    _guestHost.guestView=nil; [_guestView removeFromSuperview]; _guestView=nil; [_session close]; [self removeFromSuperview];
}
- (void)setHostVisible:(BOOL)visible {
    _hostHidden=!visible;
    [_session setVisible:visible && _model.state!=MWWindowMinimized];
}
- (void)dealloc { [_session close]; }
@end
