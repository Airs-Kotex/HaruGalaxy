// SPDX-License-Identifier: Apache-2.0
#include "MWGuestLaunchGate.h"
#include <assert.h>
#include <stdio.h>
int main(void) {
    MWGuestLaunchGate gate={0};
    assert(!MWGuestLaunchAllowsHandoff(&gate,false));
    assert(MWGuestLaunchResolved(&gate,42)==MWGuestLaunchReset);
    assert(!MWGuestLaunchAllowsHandoff(&gate,true));
    assert(MWGuestLaunchResolved(&gate,42)==MWGuestLaunchIgnore);
    assert(MWGuestLaunchResetFinished(&gate,true)==MWGuestLaunchRelaunch);
    assert(!MWGuestLaunchAllowsHandoff(&gate,false));
    assert(MWGuestLaunchResolved(&gate,77)==MWGuestLaunchAttach);
    assert(MWGuestLaunchAllowsHandoff(&gate,false));
    assert(!MWGuestLaunchAllowsHandoff(&gate,true));
    assert(MWGuestLaunchResolved(&gate,77)==MWGuestLaunchIgnore);
    gate=(MWGuestLaunchGate){0};
    assert(MWGuestLaunchResolved(&gate,42)==MWGuestLaunchReset);
    MWGuestLaunchCancel(&gate);
    assert(MWGuestLaunchResetFinished(&gate,true)==MWGuestLaunchIgnore);
    gate=(MWGuestLaunchGate){0};
    assert(MWGuestLaunchResolved(&gate,42)==MWGuestLaunchReset);
    assert(MWGuestLaunchResetFinished(&gate,false)==MWGuestLaunchFail);
    assert(MWGuestLaunchResolved(&gate,77)==MWGuestLaunchIgnore);
    gate=(MWGuestLaunchGate){0};
    assert(MWGuestLaunchResolved(&gate,42)==MWGuestLaunchReset);
    assert(MWGuestLaunchResetFinished(&gate,true)==MWGuestLaunchRelaunch);
    assert(MWGuestLaunchResolved(&gate,42)==MWGuestLaunchFail);
    gate=(MWGuestLaunchGate){0}; assert(MWGuestLaunchResolved(&gate,0)==MWGuestLaunchFail);
    puts("PASS: resolve/reset/exit/relaunch/attach order, rejection, cancellation and reused PID refusal");
}
