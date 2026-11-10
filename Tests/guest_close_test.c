// SPDX-License-Identifier: Apache-2.0
#include "MWGuestCloseState.h"
#include <assert.h>
#include <stdio.h>
#include <errno.h>
int main(void) {
    assert(MWGuestProcessAbsent(-1,ESRCH));
    assert(!MWGuestProcessAbsent(-1,EPERM));
    assert(!MWGuestProcessAbsent(0,0));
    assert(!MWGuestProcessAbsent(0,ESRCH));
    MWGuestCloseState s;
    MWGuestCloseBegin(&s,10);
    assert(MWGuestCloseObserve(&s,12,false)==MWGuestCloseWait);
    assert(MWGuestCloseObserve(&s,13,false)==MWGuestCloseReportPending);
    assert(!MWGuestCloseDone(&s)); // Timeout never pretends XPC was cancelled.
    assert(MWGuestCloseObserve(&s,100,false)==MWGuestCloseWait);
    assert(MWGuestCloseObserve(&s,101,true)==MWGuestCloseCompleteExit);
    assert(MWGuestCloseDone(&s));
    assert(MWGuestCloseReject(&s)==MWGuestCloseIgnore); // Late rejection after observed exit.
    assert(MWGuestCloseObserve(&s,102,true)==MWGuestCloseIgnore);
    MWGuestCloseBegin(&s,0);
    assert(MWGuestCloseReject(&s)==MWGuestCloseCompleteFailure);
    assert(MWGuestCloseReject(&s)==MWGuestCloseIgnore);
    assert(MWGuestCloseObserve(&s,4,true)==MWGuestCloseIgnore);
    MWGuestCloseBegin(&s,0);
    assert(MWGuestCloseObserve(&s,0,true)==MWGuestCloseCompleteExit);
    puts("PASS: explicit close deadline, pending is not cancellation, exit before reply, and exactly-once completion");
}
