// SPDX-License-Identifier: Apache-2.0
#include "MWEdgeInteraction.h"
#include <math.h>

static bool live(const MWEdgeInteraction *s) {
    return s && (s->phase==MWEdgePressed || s->phase==MWEdgeHeld ||
                 s->phase==MWEdgeMoving || s->phase==MWEdgePulled);
}
void MWEdgeTouchBegin(MWEdgeInteraction *s,double x,double y,double time,bool right,bool allowsPull) {
    *s=(MWEdgeInteraction){.phase=MWEdgePressed,.startX=x,.startY=y,.lastX=x,.lastY=y,.beganAt=time,
        .maxDistance=0,.right=right,.allowsPull=allowsPull};
    if(!isfinite(x)||!isfinite(y)||!isfinite(time)) s->phase=MWEdgeRejected;
}
unsigned MWEdgeTouchHold(MWEdgeInteraction *s,double time) {
    if(!s || s->phase!=MWEdgePressed || !isfinite(time)) return MWEdgeActionNone;
    if(time-s->beganAt>=0.35 && s->maxDistance<=12) {
        s->heldX=s->lastX; s->heldY=s->lastY;
        s->phase=MWEdgeHeld; return MWEdgeActionArmed;
    }
    return MWEdgeActionNone;
}
unsigned MWEdgeTouchUpdate(MWEdgeInteraction *s,double x,double y,double time) {
    if(!live(s)) return MWEdgeActionNone;
    if(!isfinite(x)||!isfinite(y)||!isfinite(time)) return MWEdgeTouchCancel(s);
    double dx=x-s->startX,dy=y-s->startY,distance=hypot(dx,dy);
    s->lastX=x; s->lastY=y;
    s->maxDistance=fmax(s->maxDistance,distance);
    if(s->phase==MWEdgeMoving) return MWEdgeActionMove;
    if(s->phase==MWEdgePulled) return MWEdgeActionNone;
    unsigned action=MWEdgeTouchHold(s,time);
    if(s->phase==MWEdgeHeld) {
        // Repositioning starts from the haptic location, excluding any small
        // settling drift that happened before the hold was armed.
        if(hypot(x-s->heldX,y-s->heldY)>=6) {
            s->phase=MWEdgeMoving; return action|MWEdgeActionMoveBegin|MWEdgeActionMove;
        }
        return action;
    }
    double inward=s->right ? -dx : dx;
    if(s->allowsPull && inward>=18 && fabs(dy)<=fmax(18,inward*0.75)) {
        s->phase=MWEdgePulled; return action|MWEdgeActionPullReady;
    }
    if(distance>24) s->phase=MWEdgeRejected;
    return action;
}
unsigned MWEdgeTouchEnd(MWEdgeInteraction *s,double x,double y,double time) {
    if(!live(s)) return MWEdgeActionNone;
    MWEdgeTouchPhase before=s->phase;
    unsigned action=MWEdgeTouchUpdate(s,x,y,time);
    // Movement must be observed while tracking, not inferred for the first
    // time from the release sample of a slightly drifting long tap.
    if(before!=MWEdgeMoving && s->phase==MWEdgeMoving && s->maxDistance<=24) {
        s->phase=MWEdgeHeld;
        action&=~(MWEdgeActionMoveBegin|MWEdgeActionMove);
    }
    if(s->phase==MWEdgeMoving) action|=MWEdgeActionMoveEnd;
    else if(s->phase==MWEdgePressed || s->phase==MWEdgeHeld) {
        if(s->maxDistance<=24) action|=MWEdgeActionTap;
    } else if(s->phase==MWEdgePulled) {
        double inward=s->right ? s->startX-x : x-s->startX;
        if(inward>=12 && fabs(y-s->startY)<=fmax(24,inward*0.75))
            action|=MWEdgeActionPullOpen;
    }
    s->phase=MWEdgeFinished;
    return action;
}
unsigned MWEdgeTouchCancel(MWEdgeInteraction *s) {
    if(!s) return MWEdgeActionNone;
    unsigned action=s->phase==MWEdgeMoving ? MWEdgeActionMoveCancel : MWEdgeActionNone;
    s->phase=MWEdgeFinished;
    return action;
}
