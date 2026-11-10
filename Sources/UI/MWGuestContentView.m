// SPDX-License-Identifier: Apache-2.0
#import "MWGuestContentView.h"
#import "../Core/MWWindowModel.h"
#import "../Core/MWSceneGeometry.h"

@interface MWGuestPresentationContainer : UIView
@property(nonatomic,copy) void (^geometryChanged)(void);
@end
@implementation MWGuestPresentationContainer
- (void)layoutSubviews { [super layoutSubviews]; if(self.geometryChanged) self.geometryChanged(); }
- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
    // Our native-axis bounding box may extend beyond the logical viewport;
    // the outer content view performs the visible-viewport clipping.
    for(UIView *child in self.subviews) {
        if(!child.hidden && child.alpha>.01 && child.userInteractionEnabled &&
           [child pointInside:[child convertPoint:point fromView:self] withEvent:event]) return YES;
    }
    return NO;
}
@end

@implementation MWGuestContentView {
    UIView *_logicalContainer;
    MWGuestPresentationContainer *_presentationContainer;
    BOOL _normalizing;
}
- (instancetype)init {
    if((self=[super initWithFrame:CGRectZero])) {
        self.clipsToBounds=YES; self.opaque=NO;
        _logicalContainer=[UIView new]; _logicalContainer.opaque=NO;
        _logicalContainer.layer.anchorPoint=CGPointZero;
        _logicalContainer.layer.position=CGPointZero;
        [self addSubview:_logicalContainer];
        _presentationContainer=[MWGuestPresentationContainer new];
        _presentationContainer.layer.anchorPoint=CGPointZero;
        _presentationContainer.layer.position=CGPointZero;
        [_logicalContainer addSubview:_presentationContainer];
        __weak typeof(self) weakSelf=self;
        _presentationContainer.geometryChanged=^{[weakSelf normalizePresentation];};
    }
    return self;
}
- (void)setGuestView:(UIView *)guestView {
    if(_guestView==guestView) return;
    [_guestView removeFromSuperview]; _guestView=guestView;
    if(guestView) {
        // FBScene owns its bounds/center/rotation. A transformed presenter must
        // not also be stretched by UIView autoresizing in oriented axes.
        guestView.autoresizingMask=UIViewAutoresizingNone;
        [_presentationContainer addSubview:guestView];
    }
    [self setNeedsLayout];
}
- (void)setLogicalSize:(CGSize)logicalSize {
    if(!isfinite(logicalSize.width) || !isfinite(logicalSize.height) || logicalSize.width<1 || logicalSize.height<1) return;
    if(CGSizeEqualToSize(_logicalSize,logicalSize)) return;
    _logicalSize=logicalSize; [self setNeedsLayout];
}
- (void)layoutSubviews {
    [super layoutSubviews];
    if(_logicalSize.width<1 || _logicalSize.height<1) return;
    MWContentTransform placement=MWFitContent(_logicalSize.width,_logicalSize.height,self.bounds.size.width,self.bounds.size.height);
    // UIKit owns the guest's presentation transform. Keep our scale on a
    // separate parent so guest scene layout cannot reset it.
    [CATransaction begin]; [CATransaction setDisableActions:YES];
    _logicalContainer.bounds=(CGRect){CGPointZero,_logicalSize};
    _logicalContainer.layer.position=CGPointMake(placement.x,placement.y);
    _logicalContainer.transform=CGAffineTransformMakeScale(placement.scale,placement.scale);
    [self normalizePresentation];
    [CATransaction commit];
}
- (void)normalizePresentation {
    if(_normalizing || !_guestView || _logicalSize.width<1 || _logicalSize.height<1) return;
    CGSize size=_guestView.bounds.size;
    if(!isfinite(size.width) || !isfinite(size.height) || size.width<1 || size.height<1) return;
    // Sample UIKit's actual local->parent mapping, including its anchor,
    // translation and bounds origin. Cancel it on OUR parent only, preserving
    // both the remote surface and UIKit's touch-coordinate transform.
    CGPoint p=_guestView.bounds.origin;
    CGPoint origin=[_guestView convertPoint:p toView:_presentationContainer];
    CGPoint x=[_guestView convertPoint:CGPointMake(p.x+1,p.y) toView:_presentationContainer];
    CGPoint y=[_guestView convertPoint:CGPointMake(p.x,p.y+1) toView:_presentationContainer];
    MWRect native; MWAffine normal;
    if(!MWNormalizePresentation((MWAffine){x.x-origin.x,x.y-origin.y,y.x-origin.x,y.y-origin.y,origin.x,origin.y},
        size.width,size.height,_logicalSize.width,_logicalSize.height,&native,&normal)) return;
    CGRect nativeBounds=CGRectMake(native.x,native.y,native.width,native.height);
    // Bounds cover the entire rotated child for UIKit and WindowServer hit
    // testing. Account for a nonzero native origin in our parent transform.
    CGAffineTransform transform=CGAffineTransformMake(normal.a,normal.b,normal.c,normal.d,normal.tx,normal.ty);
    _normalizing=YES;
    [CATransaction begin]; [CATransaction setDisableActions:YES];
    if(!CGRectEqualToRect(_presentationContainer.bounds,nativeBounds)) _presentationContainer.bounds=nativeBounds;
    if(!CGAffineTransformEqualToTransform(_presentationContainer.transform,transform)) _presentationContainer.transform=transform;
    [CATransaction commit]; _normalizing=NO;
}
- (NSDictionary *)geometrySnapshot {
    CGAffineTransform owned=_logicalContainer.transform,guest=_guestView.transform,normal=_presentationContainer.transform;
    return @{@"logicalWidth":@(_logicalSize.width),@"logicalHeight":@(_logicalSize.height),
        @"viewportWidth":@(self.bounds.size.width),@"viewportHeight":@(self.bounds.size.height),
        @"scaleX":@(owned.a),@"scaleY":@(owned.d),@"offsetX":@(_logicalContainer.layer.position.x),@"offsetY":@(_logicalContainer.layer.position.y),
        @"guestClass":_guestView ? NSStringFromClass(_guestView.class) : @"none",
        @"guestWidth":@(_guestView.bounds.size.width),@"guestHeight":@(_guestView.bounds.size.height),
        @"normalization":@[@(normal.a),@(normal.b),@(normal.c),@(normal.d),@(normal.tx),@(normal.ty)],
        @"presenterBoundsOwnedByUIKit":@YES,
        @"guestTransform":@[@(guest.a),@(guest.b),@(guest.c),@(guest.d),@(guest.tx),@(guest.ty)]};
}
@end
