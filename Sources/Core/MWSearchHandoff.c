// SPDX-License-Identifier: Apache-2.0
#include "MWSearchHandoff.h"

uint64_t MWSearchHandoffBegin(MWSearchHandoff *s,double now) {
    s->generation++; s->phase=MWSearchWaiting;
    s->deadline=now+6.0; s->sceneFallbackAt=now+0.6; s->sceneRequested=false;
    return s->generation;
}
bool MWSearchHandoffCurrent(const MWSearchHandoff *s,uint64_t generation) {
    return s && s->generation==generation &&
        (s->phase==MWSearchWaiting || s->phase==MWSearchPresenting || s->phase==MWSearchActive);
}
void MWSearchHandoffLaunchResult(MWSearchHandoff *s,uint64_t generation,bool accepted,double now) {
    if(MWSearchHandoffCurrent(s,generation) && s->phase==MWSearchWaiting && !accepted)
        s->sceneFallbackAt=now;
}
MWSearchAction MWSearchHandoffObserve(MWSearchHandoff *s,uint64_t generation,double now,bool foreground,bool presenterReady) {
    if(!MWSearchHandoffCurrent(s,generation) || s->phase==MWSearchActive) return MWSearchIgnore;
    if(now>=s->deadline) { s->phase=MWSearchFailed; return MWSearchAbort; }
    if(s->phase==MWSearchPresenting) return MWSearchWait;
    if(foreground && presenterReady) { s->phase=MWSearchPresenting; return MWSearchPresent; }
    if(!foreground && !s->sceneRequested && now>=s->sceneFallbackAt) {
        s->sceneRequested=true; return MWSearchActivateScene;
    }
    return MWSearchWait;
}
bool MWSearchHandoffPresented(MWSearchHandoff *s,uint64_t generation) {
    if(!MWSearchHandoffCurrent(s,generation) || s->phase!=MWSearchPresenting) return false;
    s->phase=MWSearchActive; return true;
}
void MWSearchHandoffFinish(MWSearchHandoff *s) {
    if(!s) return;
    s->generation++; s->phase=MWSearchIdle;
}
