#include "MWNativeHandoff.h"
#include <assert.h>
#include <stdio.h>

int main(void) {
    assert(MWNativeHandoffChoose(false,true,true)==MWNativeRouteSettings);
    assert(MWNativeHandoffChoose(true,true,true)==MWNativeRouteDeactivate);
    assert(MWNativeHandoffChoose(true,false,true)==MWNativeRouteDeactivate);
    assert(MWNativeHandoffChoose(false,false,true)==MWNativeRouteUnavailable);
    assert(MWNativeHandoffChoose(true,true,false)==MWNativeRouteUnavailable);
    MWNativeHandoff state={0};
    uint64_t first=MWNativeHandoffBegin(&state,10);
    assert(MWNativeHandoffObserve(&state,first,10)==MWNativeWait);
    // No launch before both a deactivation acknowledgement and local release.
    assert(MWNativeHandoffReleased(&state,first,true)==MWNativeIgnore);
    assert(!MWNativeHandoffBegin(&state,10.1));
    assert(MWNativeHandoffDeactivated(&state,first));
    assert(!MWNativeHandoffDeactivated(&state,first));
    assert(MWNativeHandoffObserve(&state,first,10.2)==MWNativeRelease);
    assert(MWNativeHandoffReleased(&state,first,true)==MWNativeOpen);
    assert(MWNativeHandoffReleased(&state,first,true)==MWNativeIgnore);
    uint64_t second=MWNativeHandoffBegin(&state,20);
    assert(!MWNativeHandoffDeactivated(&state,first));
    assert(MWNativeHandoffObserve(&state,second,22.1)==MWNativeAbort);
    assert(!MWNativeHandoffDeactivated(&state,second));
    second=MWNativeHandoffBegin(&state,30);
    MWNativeHandoffCancel(&state); // lock, background, close or replacement
    assert(!MWNativeHandoffDeactivated(&state,second));
    assert(MWNativeHandoffObserve(&state,second,30.2)==MWNativeIgnore);
    assert(MWNativeHandoffReleased(&state,second,true)==MWNativeIgnore);
    second=MWNativeHandoffBegin(&state,40);
    assert(MWNativeHandoffDeactivated(&state,second));
    assert(MWNativeHandoffObserve(&state,second,40.1)==MWNativeRelease);
    assert(MWNativeHandoffReleased(&state,second,false)==MWNativeAbort);
    second=MWNativeHandoffBegin(&state,45);
    assert(MWNativeHandoffDeactivated(&state,second));
    assert(MWNativeHandoffObserve(&state,second,45.1)==MWNativeRelease);
    MWNativeHandoffCancel(&state);
    assert(MWNativeHandoffReleased(&state,second,true)==MWNativeIgnore);
    second=MWNativeHandoffBegin(&state,50);
    assert(MWNativeHandoffDeactivated(&state,second));
    assert(MWNativeHandoffObserve(&state,second,52)==MWNativeAbort);
    puts("PASS: native handoff waits for deactivation/release, rejects timeout/failure and stale callbacks");
    return 0;
}
