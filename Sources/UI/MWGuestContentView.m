// SPDX-License-Identifier: Apache-2.0
#import "MWGuestContentView.h"
#import "../Core/MWWindowModel.h"

@implementation MWGuestContentView {
    UIView *_logicalContainer;
}
- (instancetype)init {
    if((self=[super initWithFrame:CGRectZero])) {
        self.clipsToBounds=YES; self.opaque=NO;
        _logicalContainer=[UIView new]; _logicalContainer.opaque=NO;
        _logicalContainer.layer.anchorPoint=CGPointZero;
        _logicalContainer.layer.position=CGPointZero;
        [self addSubview:_logicalContainer];
    }
    return self;
}
- (void)setGuestView:(UIView *)guestView {
    if(_guestView==guestView) return;
    [_guestView removeFromSuperview]; _guestView=guestView;
    if(guestView) {
        guestView.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
        [_logicalContainer addSubview:guestView];
    }
    [self setNeedsLayout];
}
- (void)setLogicalSize:(CGSize)logicalSize {
    if(!isfinite(logicalSize.width) || !isfinite(logicalSize.height) || logicalSize.width<1 || logicalSize.height<1) return;
    _logicalSize=logicalSize; [self setNeedsLayout];
}
- (void)layoutSubviews {
    [super layoutSubviews];
    if(_logicalSize.width<1 || _logicalSize.height<1) return;
    MWContentTransform placement=MWFitContent(_logicalSize.width,_logicalSize.height,self.bounds.size.width,self.bounds.size.height);
    // UIKit owns the guest's presentation transform. Keep our scale on a
    // separate parent so guest scene layout cannot reset it.
    _logicalContainer.bounds=(CGRect){CGPointZero,_logicalSize};
    _logicalContainer.layer.position=CGPointMake(placement.x,placement.y);
    _logicalContainer.transform=CGAffineTransformMakeScale(placement.scale,placement.scale);
    _guestView.bounds=(CGRect){CGPointZero,_logicalSize};
    _guestView.center=CGPointMake(_logicalSize.width/2,_logicalSize.height/2);
}
- (NSDictionary *)geometrySnapshot {
    CGAffineTransform owned=_logicalContainer.transform,guest=_guestView.transform;
    return @{@"logicalWidth":@(_logicalSize.width),@"logicalHeight":@(_logicalSize.height),
        @"viewportWidth":@(self.bounds.size.width),@"viewportHeight":@(self.bounds.size.height),
        @"scaleX":@(owned.a),@"scaleY":@(owned.d),@"offsetX":@(_logicalContainer.layer.position.x),@"offsetY":@(_logicalContainer.layer.position.y),
        @"guestClass":_guestView ? NSStringFromClass(_guestView.class) : @"none",
        @"guestWidth":@(_guestView.bounds.size.width),@"guestHeight":@(_guestView.bounds.size.height),
        @"guestTransform":@[@(guest.a),@(guest.b),@(guest.c),@(guest.d),@(guest.tx),@(guest.ty)]};
}
@end
