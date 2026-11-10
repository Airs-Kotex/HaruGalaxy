// SPDX-License-Identifier: Apache-2.0
#import "MWDeviceOrientation.h"
#import "../Core/MWGuestPolicy.h"
#import "../Diagnostics/MWDiagnostics.h"
NSString *const MWDeviceOrientationDidChangeNotification=@"MWDeviceOrientationDidChange";
_Static_assert((int)UIInterfaceOrientationLandscapeRight==(int)UIDeviceOrientationLandscapeLeft,"UIKit landscape values");
_Static_assert((int)UIInterfaceOrientationLandscapeLeft==(int)UIDeviceOrientationLandscapeRight,"UIKit landscape values");
_Static_assert((int)UIInterfaceOrientationLandscapeRight==3 && (int)UIInterfaceOrientationLandscapeLeft==4,"Portable orientation values");
@implementation MWDeviceOrientation {
    BOOL _started;
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
- (void)stop {
    if(!_started) return;
    _started=NO;
    [NSNotificationCenter.defaultCenter removeObserver:self name:UIDeviceOrientationDidChangeNotification object:UIDevice.currentDevice];
    [UIDevice.currentDevice endGeneratingDeviceOrientationNotifications];
}
- (void)dealloc { [self stop]; }
@end
