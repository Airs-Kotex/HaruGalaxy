// SPDX-License-Identifier: Apache-2.0
#include "MWGuestPolicy.h"
#include <assert.h>
#include <stdio.h>

int main(void) {
    for(int state=MWWindowLoading;state<=MWWindowParked;state++)
        for(int host=0;host<2;host++) for(int keep=0;keep<2;keep++) {
            MWGuestExecution p=MWGuestExecutionForState((MWWindowState)state,host,keep);
            assert(p.keepAlive==(state==MWWindowMinimized && keep));
            assert(p.presented==(host && (state==MWWindowVisible || state==MWWindowParked || state==MWWindowLoading)));
            assert(!(p.presented && p.keepAlive));
        }
    assert(MWInterfaceOrientationForDevice(3,1)==3);
    assert(MWInterfaceOrientationForDevice(4,1)==4);
    assert(MWInterfaceOrientationForDevice(1,3)==1);
    assert(MWInterfaceOrientationForDevice(2,1)==2);
    for(int old=1;old<=4;old++) {
        assert(MWInterfaceOrientationForDevice(0,old)==old);
        assert(MWInterfaceOrientationForDevice(5,old)==old);
        assert(MWInterfaceOrientationForDevice(6,old)==old);
        assert(MWInterfaceOrientationForDevice(-1,old)==old);
        assert(MWInterfaceOrientationForDevice(MWDeviceOrientationForInterface(old),1)==old);
        assert(MWOrientationQuarterTurns(old)-MWOrientationQuarterTurns(old)==0);
    }
    assert(MWInterfaceOrientationForDevice(0,0)==1);
    assert(MWOrientationQuarterTurns(1)==0);
    assert(MWOrientationQuarterTurns(2)==2);
    assert(MWOrientationQuarterTurns(3)==1);
    assert(MWOrientationQuarterTurns(4)==-1);
    puts("PASS: minimized execution, sensor direction mapping, flat-device fallback and canvas rotation");
}
