// SPDX-License-Identifier: Apache-2.0
#import "MWDeviceOrientation.h"
#import "../Core/MWGuestPolicy.h"
#import "../Core/MWSceneGeometry.h"
#import "../Core/MWOrientationState.h"
#import "../Core/MWRuntimeTypes.h"
#import "../Diagnostics/MWDiagnostics.h"
#import "MWPrivate.h"
#import "MWRuntimeDiagnostics.h"
#import <CoreMotion/CoreMotion.h>
#import <objc/message.h>
#import <objc/runtime.h>
#include <string.h>
NSString *const MWDeviceOrientationDidChangeNotification=@"MWDeviceOrientationDidChange";
_Static_assert((int)UIInterfaceOrientationLandscapeRight==(int)UIDeviceOrientationLandscapeLeft,"UIKit landscape values");
_Static_assert((int)UIInterfaceOrientationLandscapeLeft==(int)UIDeviceOrientationLandscapeRight,"UIKit landscape values");
_Static_assert((int)UIInterfaceOrientationLandscapeRight==3 && (int)UIInterfaceOrientationLandscapeLeft==4,"Portable orientation values");
static BOOL MWOrientationMethod(Class cls,SEL selector,char result,const char *arguments) {
    Method method=cls ? class_getInstanceMethod(cls,selector) : NULL;
    if(!method || method_getNumberOfArguments(method)!=strlen(arguments)+2) return NO;
    char type[128]={0}; method_getReturnType(method,type,sizeof(type));
    if(!MWObjCTypeMatches(type,result)) return NO;
    for(unsigned i=0;arguments[i];i++) {
        method_getArgumentType(method,i+2,type,sizeof(type));
        if(!MWObjCTypeMatches(type,arguments[i])) return NO;
    }
    return YES;
}
@implementation MWDeviceOrientation {
    BOOL _started;
    MWOrientationState _state;
    id _systemObserver;
    NSUInteger _systemUpdates,_systemRejected;
    CMMotionManager *_motion;
    NSOperationQueue *_motionQueue;
    NSUInteger _motionSamples,_stableSamples,_unclassifiedSamples;
    int _candidate;
    CFTimeInterval _lastMotion;
}
- (UIInterfaceOrientation)orientation { return (UIInterfaceOrientation)_state.orientation; }
- (UIInterfaceOrientation)orientationForHost:(UIInterfaceOrientation)host floating:(BOOL)floating {
    return (UIInterfaceOrientation)MWWorkspaceOrientation(&_state,floating,(int)host);
}
- (void)start {
    if(_started) return;
    _started=YES;
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(changed:)
        name:UIDeviceOrientationDidChangeNotification object:UIDevice.currentDevice];
    [UIDevice.currentDevice beginGeneratingDeviceOrientationNotifications];
    [self changed:nil];
}
- (void)changed:(NSNotification *)notification {
    if(!_state.active) return;
    // A recent gravity reading takes precedence over a stale UIKit enum
    // while the app's normal scene is backgrounded.
    if(_lastMotion>0 && CACurrentMediaTime()-_lastMotion<1) return;
    UIDeviceOrientation device=UIDevice.currentDevice.orientation;
    // No physical orientation has been observed yet: let the host supply the
    // initial direction. A flat phone never chooses portrait on its own.
    if(device<UIDeviceOrientationPortrait || device>UIDeviceOrientationLandscapeRight) return;
    int next=MWInterfaceOrientationForDevice((int)device,_state.orientation);
    BOOL foreground=UIApplication.sharedApplication.applicationState==UIApplicationStateActive;
    if(!MWOrientationObserveDevice(&_state,_state.generation,next,foreground,notification==nil)) return;
    MWLog(@"orientation.device",@{@"device":@(device),@"interface":@(_state.orientation),@"source":@"device_notification"});
    [NSNotificationCenter.defaultCenter postNotificationName:MWDeviceOrientationDidChangeNotification object:self];
}
- (void)receiveSystemOrientation:(id)value generation:(uint64_t)generation {
    if(!_state.active || _state.generation!=generation || !_systemObserver) return;
    NSInteger orientation=[value isKindOfClass:NSNumber.class] ? [value integerValue] : 0;
    if(orientation<1 || orientation>4) {
        if(_systemRejected++==0) MWLog(@"orientation.system_unavailable",@{@"reason":@"invalid_orientation"});
        return;
    }
    _systemUpdates++;
    if(!MWOrientationObserveSystem(&_state,generation,(int)orientation)) return;
    MWLog(@"orientation.system",@{@"interface":@(orientation),@"generation":@(generation),@"updates":@(_systemUpdates)});
    [NSNotificationCenter.defaultCenter postNotificationName:MWDeviceOrientationDidChangeNotification object:self];
}
- (void)startSystemObserver:(uint64_t)generation {
    MWLoadPrivateFrameworks();
    Class cls=NSClassFromString(@"FBSOrientationObserver");
    SEL handler=NSSelectorFromString(@"setHandler:"),invalidate=NSSelectorFromString(@"invalidate");
    if(!MWOrientationMethod(cls,@selector(init),'@',"") ||
       !MWOrientationMethod(cls,handler,'v',"@") || !MWOrientationMethod(cls,invalidate,'v',"")) {
        MWLog(@"orientation.system_unavailable",@{@"reason":@"observer_abi_unavailable"});
        return;
    }
    @try {
        _systemObserver=[[cls alloc] init];
        if(!_systemObserver) { MWLog(@"orientation.system_unavailable",@{@"reason":@"observer_init_failed"}); return; }
        __weak typeof(self) weakSelf=self;
        void (^callback)(id)=^(id update) {
            // The private observer does not promise our main queue. Validate the
            // value on that queue; teardown/resume invalidates queued callbacks.
            dispatch_async(dispatch_get_main_queue(),^{
                MWDeviceOrientation *owner=weakSelf;
                if(!owner || !owner->_state.active || owner->_state.generation!=generation) return;
                [owner receiveSystemOrientation:MWRuntimeIntegerValue(update,@"orientation") generation:generation];
            });
        };
        ((void(*)(id,SEL,id))objc_msgSend)(_systemObserver,handler,callback);
        MWLog(@"orientation.system_started",@{@"generation":@(generation)});
        [self receiveSystemOrientation:MWRuntimeIntegerValue(_systemObserver,@"activeInterfaceOrientation") generation:generation];
    } @catch(NSException *exception) {
        MWLog(@"orientation.system_unavailable",@{@"reason":@"observer_exception",@"exception":exception.name});
        [self stopSystemObserver];
    }
}
- (void)stopSystemObserver {
    id observer=_systemObserver; _systemObserver=nil;
    if(!observer) return;
    @try { ((void(*)(id,SEL,id))objc_msgSend)(observer,NSSelectorFromString(@"setHandler:"),nil); }
    @catch(NSException *exception) { (void)exception; }
    @try { ((void(*)(id,SEL))objc_msgSend)(observer,NSSelectorFromString(@"invalidate")); }
    @catch(NSException *exception) { (void)exception; }
    MWLog(@"orientation.system_stopped",@{});
}
- (void)setTrackingEnabled:(BOOL)enabled {
    if(_state.active==enabled) return;
    uint64_t generation=MWOrientationSetActive(&_state,enabled);
    [_motion stopDeviceMotionUpdates]; _candidate=0; _stableSamples=0; _lastMotion=0;
    [self stopSystemObserver];
    if(!enabled) { MWLog(@"orientation.motion_stopped",@{}); return; }
    // UIDevice is a possibly stale seed, not a newly measured physical sample.
    // Apply an eligible foreground seed first; the system snapshot wins next.
    [self changed:nil];
    [self startSystemObserver:generation];
    if(!_motion) _motion=[CMMotionManager new];
    if(!_motion.deviceMotionAvailable) { MWLog(@"orientation.motion_unavailable",@{@"reason":@"sensor_unavailable"}); return; }
    if(!_motionQueue) { _motionQueue=[NSOperationQueue new]; _motionQueue.maxConcurrentOperationCount=1; _motionQueue.qualityOfService=NSQualityOfServiceUtility; }
    _motion.deviceMotionUpdateInterval=.2;
    __weak typeof(self) weakSelf=self;
    [_motion startDeviceMotionUpdatesToQueue:_motionQueue withHandler:^(CMDeviceMotion *sample,NSError *error) {
        int direction=sample ? MWOrientationFromGravity(sample.gravity.x,sample.gravity.y,sample.gravity.z) : 0;
        dispatch_async(dispatch_get_main_queue(),^{
            MWDeviceOrientation *owner=weakSelf;
            if(!owner || !owner->_state.active || owner->_state.generation!=generation) return;
            if(error) {
                MWLog(@"orientation.motion_unavailable",@{@"reason":@"sample_error",@"error":MWErrorFields(error)});
                [owner->_motion stopDeviceMotionUpdates];
                owner->_lastMotion=0; owner->_candidate=0; owner->_stableSamples=0;
                // Keep the independent system observer and UIDevice fallback.
                return;
            }
            if(!sample) return;
            owner->_lastMotion=CACurrentMediaTime(); owner->_motionSamples++;
            if(owner->_motionSamples==1) MWLog(@"orientation.motion_receiving",@{@"interval":@0.2});
            if(!direction) { owner->_candidate=0; owner->_stableSamples=0; owner->_unclassifiedSamples++; return; }
            if(direction!=owner->_candidate) { owner->_candidate=direction; owner->_stableSamples=1; return; }
            if(owner->_stableSamples<2) owner->_stableSamples++;
            if(!MWOrientationObservePhysical(&owner->_state,generation,direction)) return;
            MWLog(@"orientation.device",@{@"interface":@(direction),@"source":@"gravity",@"stableSamples":@(owner->_stableSamples)});
            [NSNotificationCenter.defaultCenter postNotificationName:MWDeviceOrientationDidChangeNotification object:owner];
        });
    }];
    MWLog(@"orientation.motion_started",@{@"available":@YES,@"interval":@0.2});
}
- (NSDictionary *)diagnosticSnapshot {
    NSString *source=_state.source==MWOrientationSourceSystem ? @"system" :
        (_state.source==MWOrientationSourcePhysical ? @"physical" : (_state.source==MWOrientationSourceDevice ? @"device_notification" : @"none"));
    return @{@"orientation":@(_state.orientation),@"motionRequested":@(_state.active),@"motionActive":@(_motion.deviceMotionActive),
        @"samples":@(_motionSamples),@"secondsSinceSample":_lastMotion>0 ? @(CACurrentMediaTime()-_lastMotion) : @"unavailable",
        @"systemObserver":@(_systemObserver!=nil),@"systemUpdates":@(_systemUpdates),@"systemRejected":@(_systemRejected),
        @"systemOrientation":@(_state.systemOrientation),@"physicalOrientation":@(_state.physicalOrientation),
        @"deviceOrientation":@(_state.deviceOrientation),
        @"source":source,@"generation":@(_state.generation),@"unclassifiedSamples":@(_unclassifiedSamples),
        @"deviceNotificationGeneration":@(UIDevice.currentDevice.generatesDeviceOrientationNotifications)};
}
- (void)stop {
    [self setTrackingEnabled:NO];
    if(!_started) return;
    _started=NO;
    [NSNotificationCenter.defaultCenter removeObserver:self name:UIDeviceOrientationDidChangeNotification object:UIDevice.currentDevice];
    [UIDevice.currentDevice endGeneratingDeviceOrientationNotifications];
}
- (void)dealloc { [self stop]; }
@end
