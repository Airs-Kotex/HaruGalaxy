// SPDX-License-Identifier: Apache-2.0
#include "MWSearchHandoff.h"
#include <assert.h>
#include <stdio.h>

int main(void) {
    MWSearchHandoff s={0};
    uint64_t g=MWSearchHandoffBegin(&s,10);
    assert(MWSearchHandoffObserve(&s,g,10,true,true)==MWSearchPresent);
    assert(MWSearchHandoffObserve(&s,g,10.1,true,true)==MWSearchWait);
    assert(MWSearchHandoffPresented(&s,g));
    assert(MWSearchHandoffObserve(&s,g,100,true,true)==MWSearchIgnore);
    MWSearchHandoffFinish(&s);
    assert(!MWSearchHandoffCurrent(&s,g));
    assert(!MWSearchHandoffPresented(&s,g));

    g=MWSearchHandoffBegin(&s,20);
    MWSearchHandoffLaunchResult(&s,g,true,20);
    assert(MWSearchHandoffObserve(&s,g,20.2,false,false)==MWSearchWait);
    assert(MWSearchHandoffObserve(&s,g,20.7,false,false)==MWSearchActivateScene);
    assert(MWSearchHandoffObserve(&s,g,20.8,false,false)==MWSearchWait);
    assert(MWSearchHandoffObserve(&s,g,21,true,false)==MWSearchWait);
    assert(MWSearchHandoffObserve(&s,g,21.1,true,true)==MWSearchPresent);
    assert(MWSearchHandoffPresented(&s,g));
    MWSearchHandoffFinish(&s);

    g=MWSearchHandoffBegin(&s,30);
    MWSearchHandoffLaunchResult(&s,g,false,30);
    assert(MWSearchHandoffObserve(&s,g,30,false,false)==MWSearchActivateScene);
    assert(MWSearchHandoffObserve(&s,g,30.1,false,false)==MWSearchWait);
    assert(MWSearchHandoffObserve(&s,g,36,false,false)==MWSearchAbort);
    assert(!MWSearchHandoffCurrent(&s,g));
    assert(MWSearchHandoffObserve(&s,g,37,true,true)==MWSearchIgnore);

    uint64_t old=g;
    g=MWSearchHandoffBegin(&s,40);
    MWSearchHandoffLaunchResult(&s,old,false,40);
    assert(MWSearchHandoffObserve(&s,old,40,true,true)==MWSearchIgnore);
    assert(MWSearchHandoffObserve(&s,g,40.1,false,false)==MWSearchWait);
    assert(MWSearchHandoffObserve(&s,g,40.2,true,true)==MWSearchPresent);
    // A presentation with no completion must not leave the overlay hidden.
    assert(MWSearchHandoffObserve(&s,g,46,true,true)==MWSearchAbort);
    assert(!MWSearchHandoffPresented(&s,g));
    g=MWSearchHandoffBegin(&s,50);
    MWSearchHandoffFinish(&s); MWSearchHandoffFinish(&s);
    assert(MWSearchHandoffObserve(&s,g,51,true,true)==MWSearchIgnore);
    puts("PASS: foreground handoff, rejected/stalled launch, presentation timeout, stale completion and cancellation");
}
