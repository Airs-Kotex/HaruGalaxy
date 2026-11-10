// SPDX-License-Identifier: Apache-2.0
#include "MWNativeHandoff.h"

MWNativeRoute MWNativeHandoffChoose(bool deactivateAvailable,bool settingsUpdateAvailable,bool cleanupAvailable) {
    if(!cleanupAvailable) return MWNativeRouteUnavailable;
    if(deactivateAvailable) return MWNativeRouteDeactivate;
    return settingsUpdateAvailable ? MWNativeRouteSettings : MWNativeRouteUnavailable;
}
uint64_t MWNativeHandoffBegin(MWNativeHandoff *s,double now) {
    if(!s || (s->phase!=MWNativeIdle && s->phase!=MWNativeFinished)) return 0;
    s->generation++; s->phase=MWNativeWaiting; s->deadline=now+2;
    return s->generation;
}
bool MWNativeHandoffDeactivated(MWNativeHandoff *s,uint64_t generation) {
    if(!s || s->generation!=generation || s->phase!=MWNativeWaiting) return false;
    s->phase=MWNativeDeactivated; return true;
}
MWNativeAction MWNativeHandoffObserve(MWNativeHandoff *s,uint64_t generation,double now) {
    if(!s || s->generation!=generation || (s->phase!=MWNativeWaiting && s->phase!=MWNativeDeactivated)) return MWNativeIgnore;
    if(now>=s->deadline) { s->phase=MWNativeFinished; return MWNativeAbort; }
    if(s->phase==MWNativeDeactivated) { s->phase=MWNativeReleasing; return MWNativeRelease; }
    return MWNativeWait;
}
MWNativeAction MWNativeHandoffReleased(MWNativeHandoff *s,uint64_t generation,bool released) {
    if(!s || s->generation!=generation || s->phase!=MWNativeReleasing) return MWNativeIgnore;
    s->phase=MWNativeFinished; return released ? MWNativeOpen : MWNativeAbort;
}
void MWNativeHandoffCancel(MWNativeHandoff *s) {
    if(!s) return;
    s->generation++; s->phase=MWNativeFinished;
}
