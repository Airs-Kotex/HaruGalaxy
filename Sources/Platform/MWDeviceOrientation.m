// SPDX-License-Identifier: Apache-2.0
#import "MWDeviceOrientation.h"
#import "../Core/MWGuestPolicy.h"
#import "../Core/MWSceneGeometry.h"
#import "../Diagnostics/MWDiagnostics.h"
#import <CoreMotion/CoreMotion.h>
NSString *const MWDeviceOrientationDidChangeNotification=@"MWDeviceOrientationDidChange";
_Static_assert((int)UIInterfaceOrientationLandscapeRight==(int)UIDeviceOrientationLandscapeLeft,"UIKit landscape values");
_Static_assert((int)UIInterfaceOrientationLandscapeLeft==(int)UIDeviceOrientationLandscapeRight,"UIKit landscape values");
_Static_assert((int)UIInterfaceOrientationLandscapeRight==3 && (int)UIInterfaceOrientationLandscapeLeft==4,"Portable orientation values");
@implementation MWDeviceOrientation {
    BOOL _started;
    CMMotionManager *_motion;
    NSOperationQueue *_motionQueue;
    NSUInteger _motionGeneration,_motionSamples,_stableSamples;
    int _candidate;
    CFTimeInterval _lastMotion;
    BOOL _motionEnabled;
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
    (void)notification;
    // A recent gravity reading takes precedence over a stale UIKit enum
    // while the app's normal scene is backgrounded.
    if(_motionEnabled && _lastMotion>0 && CACurrentMediaTime()-_lastMotion<1) return;
    UIDeviceOrientation device=UIDevice.currentDevice.orientation;
    // No physical orientation has been observed yet: let the host supply the
    // initial direction. A flat phone never chooses portrait on its own.
    if(!_orientation && (device<UIDeviceOrientationPortrait || device>UIDeviceOrientationLandscapeRight)) return;
    UIInterfaceOrientation next=MWInterfaceOrientationForDevice((int)device,(int)_orientation);
    if(next==_orientation) return;
    _orientation=next;
    MWLog(@"orientation.device",@{@"device":@(device),@"interface":@(_orientation)});
    [NSNotificationCenter.defaultCenter postNotificationName:MWDeviceOrientationDidChangeNotification object:self];
}
- (void)setMotionEnabled:(BOOL)enabled {
    if(_motionEnabled==enabled) return;
    _motionEnabled=enabled; NSUInteger generation=++_motionGeneration;
    [_motion stopDeviceMotionUpdates]; _candidate=0; _stableSamples=0; _lastMotion=0;
    if(!enabled) { MWLog(@"orientation.motion_stopped",@{}); return; }
    if(!_motion) _motion=[CMMotionManager new];
    if(!_motion.deviceMotionAvailable) { MWLog(@"orientation.motion_unavailable",@{@"reason":@"sensor_unavailable"}); return; }
    if(!_motionQueue) { _motionQueue=[NSOperationQueue new]; _motionQueue.maxConcurrentOperationCount=1; _motionQueue.qualityOfService=NSQualityOfServiceUtility; }
    _motion.deviceMotionUpdateInterval=.2;
    __weak typeof(self) weakSelf=self;
    [_motion startDeviceMotionUpdatesToQueue:_motionQueue withHandler:^(CMDeviceMotion *sample,NSError *error) {
        int direction=sample ? MWOrientationFromGravity(sample.gravity.x,sample.gravity.y,sample.gravity.z) : 0;
        dispatch_async(dispatch_get_main_queue(),^{
            MWDeviceOrientation *owner=weakSelf;
            if(!owner || !owner->_motionEnabled || owner->_motionGeneration!=generation) return;
            if(error) {
                MWLog(@"orientation.motion_unavailable",@{@"reason":@"sample_error",@"error":MWErrorFields(error)});
                [owner setMotionEnabled:NO]; return;
            }
            if(!sample) return;
            owner->_lastMotion=CACurrentMediaTime(); owner->_motionSamples++;
            if(owner->_motionSamples==1) MWLog(@"orientation.motion_receiving",@{@"interval":@0.2});
            if(!direction) { owner->_candidate=0; owner->_stableSamples=0; return; }
            if(direction!=owner->_candidate) { owner->_candidate=direction; owner->_stableSamples=1; return; }
            if(owner->_stableSamples<2) owner->_stableSamples++;
            if(owner->_orientation==direction) return;
            owner->_orientation=direction;
            MWLog(@"orientation.device",@{@"interface":@(direction),@"source":@"gravity",@"stableSamples":@(owner->_stableSamples)});
            [NSNotificationCenter.defaultCenter postNotificationName:MWDeviceOrientationDidChangeNotification object:owner];
        });
    }];
    MWLog(@"orientation.motion_started",@{@"available":@YES,@"interval":@0.2});
}
- (NSDictionary *)diagnosticSnapshot {
    return @{@"orientation":@(_orientation),@"motionRequested":@(_motionEnabled),@"motionActive":@(_motion.deviceMotionActive),
        @"samples":@(_motionSamples),@"secondsSinceSample":_lastMotion>0 ? @(CACurrentMediaTime()-_lastMotion) : @"unavailable",
        @"deviceNotificationGeneration":@(UIDevice.currentDevice.generatesDeviceOrientationNotifications)};
}
- (void)stop {
    [self setMotionEnabled:NO];
    if(!_started) return;
    _started=NO;
    [NSNotificationCenter.defaultCenter removeObserver:self name:UIDeviceOrientationDidChangeNotification object:UIDevice.currentDevice];
    [UIDevice.currentDevice endGeneratingDeviceOrientationNotifications];
}
- (void)dealloc { [self stop]; }
@end
