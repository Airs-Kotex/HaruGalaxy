#include "MWOverlayStartup.h"
#include <assert.h>
#include <stdio.h>

static void synchronous_window_then_lazy_root(void) {
    MWOverlayStartup startup={0};
    uint64_t token=MWOverlayStartupBegin(&startup,10,2);
    // iOS may connect the overlay synchronously inside scene creation, before
    // addScene has installed its presenter. Never probe the root at this point.
    MWOverlayStartupWindowConnected(&startup,token);
    assert(!MWOverlayStartupCanProbe(&startup,token));
    MWOverlayStartupSceneAdded(&startup,token);
    assert(MWOverlayStartupCanProbe(&startup,token));
    assert(MWOverlayStartupObserve(&startup,token,10.01,MWOverlayRootPending)==MWOverlayStartupWait);
    assert(MWOverlayStartupObserve(&startup,token,10.08,MWOverlayRootReady)==MWOverlayStartupComplete);
    assert(startup.phase==MWOverlayStartupReady);
    assert(!MWOverlayStartupCanProbe(&startup,token));
    assert(MWOverlayStartupObserve(&startup,token,10.09,MWOverlayRootReady)==MWOverlayStartupIgnore);
}

static void root_then_delayed_window(void) {
    MWOverlayStartup startup={0};
    uint64_t token=MWOverlayStartupBegin(&startup,20,2);
    MWOverlayStartupSceneAdded(&startup,token);
    assert(MWOverlayStartupObserve(&startup,token,20.1,MWOverlayRootReady)==MWOverlayStartupWait);
    assert(startup.rootAttached && startup.phase==MWOverlayStartupWaiting);
    MWOverlayStartupWindowConnected(&startup,token);
    assert(MWOverlayStartupObserve(&startup,token,20.2,MWOverlayRootPending)==MWOverlayStartupWait);
    assert(!startup.rootAttached);
    assert(MWOverlayStartupObserve(&startup,token,20.3,MWOverlayRootReady)==MWOverlayStartupComplete);
}

static void cancellation_and_timeout(void) {
    MWOverlayStartup startup={0};
    uint64_t old=MWOverlayStartupBegin(&startup,30,2);
    MWOverlayStartupSceneAdded(&startup,old);
    MWOverlayStartupCancel(&startup);
    assert(!MWOverlayStartupCanProbe(&startup,old));
    assert(MWOverlayStartupObserve(&startup,old,30.1,MWOverlayRootReady)==MWOverlayStartupIgnore);
    uint64_t current=MWOverlayStartupBegin(&startup,31,2);
    assert(current!=old);
    MWOverlayStartupWindowConnected(&startup,old);
    assert(!startup.windowConnected);
    MWOverlayStartupSceneAdded(&startup,current);
    assert(MWOverlayStartupObserve(&startup,current,32.99,MWOverlayRootPending)==MWOverlayStartupWait);
    assert(MWOverlayStartupObserve(&startup,current,33,MWOverlayRootPending)==MWOverlayStartupAbort);
    assert(startup.phase==MWOverlayStartupFailed);
    assert(MWOverlayStartupObserve(&startup,current,33.1,MWOverlayRootReady)==MWOverlayStartupIgnore);
    current=MWOverlayStartupBegin(&startup,34,2);
    MWOverlayStartupSceneAdded(&startup,current);
    assert(MWOverlayStartupObserve(&startup,current,34.01,MWOverlayRootRejected)==MWOverlayStartupAbort);
}

int main(void) {
    synchronous_window_then_lazy_root(); root_then_delayed_window(); cancellation_and_timeout();
    puts("PASS: lazy root startup, no pre-add probe, both callback orders, cancellation, timeout and rejection");
}
