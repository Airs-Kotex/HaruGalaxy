// SPDX-License-Identifier: Apache-2.0
#include "MWOverlayStartup.h"

static bool current(const MWOverlayStartup *s,uint64_t generation) {
    return s && s->generation==generation && s->phase==MWOverlayStartupWaiting;
}
uint64_t MWOverlayStartupBegin(MWOverlayStartup *s,double now,double timeout) {
    s->generation++;
    s->phase=MWOverlayStartupWaiting; s->deadline=now+timeout;
    s->sceneAdded=false; s->windowConnected=false; s->rootAttached=false;
    return s->generation;
}
void MWOverlayStartupSceneAdded(MWOverlayStartup *s,uint64_t generation) {
    if(current(s,generation)) s->sceneAdded=true;
}
void MWOverlayStartupWindowConnected(MWOverlayStartup *s,uint64_t generation) {
    if(current(s,generation)) s->windowConnected=true;
}
bool MWOverlayStartupCanProbe(const MWOverlayStartup *s,uint64_t generation) {
    return current(s,generation) && s->sceneAdded;
}
MWOverlayStartupAction MWOverlayStartupObserve(MWOverlayStartup *s,uint64_t generation,double now,MWOverlayRootResult result) {
    if(!MWOverlayStartupCanProbe(s,generation)) return MWOverlayStartupIgnore;
    if(result==MWOverlayRootRejected || now>=s->deadline) {
        s->phase=MWOverlayStartupFailed; return MWOverlayStartupAbort;
    }
    // Readiness is an observation of the current root, not a sticky success:
    // the binder can replace or disconnect it before the window connects.
    s->rootAttached=result==MWOverlayRootReady;
    if(s->rootAttached && s->windowConnected) {
        s->phase=MWOverlayStartupReady; return MWOverlayStartupComplete;
    }
    return MWOverlayStartupWait;
}
void MWOverlayStartupCancel(MWOverlayStartup *s) {
    if(!s) return;
    s->generation++; s->phase=MWOverlayStartupCancelled;
    s->sceneAdded=false; s->windowConnected=false; s->rootAttached=false;
}
