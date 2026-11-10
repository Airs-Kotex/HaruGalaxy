// SPDX-License-Identifier: Apache-2.0
#include "MWOrientationState.h"
#include "MWGuestPolicy.h"

bool MWOrientationIsValid(int orientation) { return orientation>=1 && orientation<=4; }
uint64_t MWOrientationSetActive(MWOrientationState *state,bool active) {
    if(state->active==active) return state->generation;
    state->active=active; state->generation++;
    // Preserve the last usable direction while hidden/flat, but establish fresh
    // source baselines when tracking resumes. Old callbacks cannot re-enter.
    state->systemOrientation=state->physicalOrientation=state->deviceOrientation=0;
    return state->generation;
}
static bool MWOrientationAccept(MWOrientationState *state,int orientation,MWOrientationSource source) {
    bool changed=state->orientation!=orientation;
    state->orientation=orientation; state->source=source;
    return changed;
}
bool MWOrientationObserveSystem(MWOrientationState *state,uint64_t generation,int orientation) {
    if(!state->active || state->generation!=generation || !MWOrientationIsValid(orientation) ||
       state->systemOrientation==orientation) return false;
    state->systemOrientation=orientation;
    return MWOrientationAccept(state,orientation,MWOrientationSourceSystem);
}
bool MWOrientationObservePhysical(MWOrientationState *state,uint64_t generation,int orientation) {
    if(!state->active || state->generation!=generation || !MWOrientationIsValid(orientation) ||
       state->physicalOrientation==orientation) return false;
    state->physicalOrientation=orientation;
    // A repeating sensor value must not undo a newer system rotation. The
    // first physical observation is usable too: a workspace can start while
    // the display is locked to portrait but the device is already landscape.
    return MWOrientationAccept(state,orientation,MWOrientationSourcePhysical);
}
bool MWOrientationObserveDevice(MWOrientationState *state,uint64_t generation,int orientation,bool foreground,bool seed) {
    if(!state->active || state->generation!=generation || !foreground || !MWOrientationIsValid(orientation) ||
       state->deviceOrientation==orientation) return false;
    state->deviceOrientation=orientation;
    if(seed && (MWOrientationIsValid(state->systemOrientation) || MWOrientationIsValid(state->physicalOrientation))) return false;
    return MWOrientationAccept(state,orientation,MWOrientationSourceDevice);
}
int MWWorkspaceOrientation(const MWOrientationState *state,bool floating,int hostOrientation) {
    // Both presentation modes retain 0.3.14's gravity-following behavior when
    // the host is rotation-locked. System/physical changes share arbitration.
    (void)floating;
    if(MWOrientationIsValid(state->orientation)) return state->orientation;
    return MWOrientationIsValid(hostOrientation) ? hostOrientation : 1;
}
int MWWorkspaceQuarterTurns(int hostOrientation,int targetOrientation) {
    int turns=MWOrientationQuarterTurns(targetOrientation)-MWOrientationQuarterTurns(hostOrientation);
    if(turns>2) turns-=4;
    if(turns<-2) turns+=4;
    return turns;
}
static bool MWOrientationAllowed(unsigned mask,int orientation) {
    return MWOrientationIsValid(orientation) && (mask & (1u<<orientation))!=0;
}
unsigned MWGuestRetainOrientationMask(MWGuestOrientationState *state,unsigned observed,int clientOrientation) {
    unsigned supported=observed & 30u;
    if(supported) {
        state->retainedMask=supported;
        // A repeated value can reassert a request before the client rotates.
        // Confirmation must belong to this observation, not an older request.
        state->maskConfirmed=false;
    }
    if(MWOrientationAllowed(state->retainedMask,clientOrientation)) {
        state->maskConfirmed=true;
    } else if(!supported && state->maskConfirmed && MWOrientationIsValid(clientOrientation)) {
        // For example, a fullscreen client returned to portrait without a new
        // mask. Require a prior matching report so a delayed pre-rotation echo
        // cannot immediately discard a newly requested landscape mask.
        state->retainedMask=0;
        state->maskConfirmed=false;
    }
    return state->retainedMask;
}
int MWGuestOrientation(int workspace,unsigned declaredMask,unsigned clientMask,int clientOrientation,int previous) {
    const unsigned all=30; // portrait, upside down, landscape right/left
    unsigned supported=clientMask & all;
    if(!supported) supported=declaredMask & all;
    int requested=MWOrientationIsValid(workspace) ? workspace : (MWOrientationIsValid(previous) ? previous : 1);
    if(!supported || MWOrientationAllowed(supported,requested)) return requested;
    if(MWOrientationAllowed(supported,clientOrientation)) return clientOrientation;
    if(MWOrientationAllowed(supported,previous)) return previous;
    const int fallback[]={1,3,4,2};
    for(unsigned i=0;i<4;i++) if(MWOrientationAllowed(supported,fallback[i])) return fallback[i];
    return requested;
}
