// SPDX-License-Identifier: Apache-2.0
#include "MWGuestCloseState.h"
#include <errno.h>
bool MWGuestProcessAbsent(int result,int error) { return result==-1 && error==ESRCH; }
void MWGuestCloseBegin(MWGuestCloseState *s,double now) {
    if(s) *s=(MWGuestCloseState){.deadline=now+3};
}
bool MWGuestCloseDone(const MWGuestCloseState *s) { return !s || s->done; }
MWGuestCloseAction MWGuestCloseObserve(MWGuestCloseState *s,double now,bool exited) {
    if(MWGuestCloseDone(s)) return MWGuestCloseIgnore;
    if(exited) { s->done=true; return MWGuestCloseCompleteExit; }
    if(now>=s->deadline && !s->reportedPending) { s->reportedPending=true; return MWGuestCloseReportPending; }
    return MWGuestCloseWait;
}
MWGuestCloseAction MWGuestCloseReject(MWGuestCloseState *s) {
    if(MWGuestCloseDone(s)) return MWGuestCloseIgnore;
    s->done=true; return MWGuestCloseCompleteFailure;
}
