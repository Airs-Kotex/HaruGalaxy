// SPDX-License-Identifier: Apache-2.0
#include "MWGuestPolicy.h"
MWGuestExecution MWGuestExecutionForState(MWWindowState state,bool hostVisible,bool keepMinimizedAlive) {
    return (MWGuestExecution){hostVisible && (state==MWWindowVisible || state==MWWindowLoading || state==MWWindowParked),
        state==MWWindowMinimized && keepMinimizedAlive};
}
int MWInterfaceOrientationForDevice(int device,int previous) {
    switch(device) {
        case 1: return 1;
        case 2: return 2;
        // UIKit already gives the oppositely named landscape enums the same
        // numeric value; exchanging 3/4 again would turn the UI upside down.
        case 3: return 3;
        case 4: return 4;
        default: return previous>=1 && previous<=4 ? previous : 1;
    }
}
int MWDeviceOrientationForInterface(int orientation) {
    return MWInterfaceOrientationForDevice(orientation,1);
}
int MWOrientationQuarterTurns(int orientation) {
    switch(orientation) {
        case 2: return 2;
        case 3: return 1;
        case 4: return -1;
        default: return 0;
    }
}
