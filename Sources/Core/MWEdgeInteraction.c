// SPDX-License-Identifier: Apache-2.0
#include "MWEdgeInteraction.h"
#include <math.h>

static bool live(const MWEdgeInteraction *s) {
    return s && (s->phase==MWEdgePressed || s->phase==MWEdgeHeld || s->phase==MWEdgeMoving);
}
void MWEdgeTouchBegin(MWEdgeInteraction *s,double x,double y,double time) {
    *s=(MWEdgeInteraction){.phase=MWEdgePressed,.startX=x,.startY=y,.beganAt=time,.maxDistance=0};
    if(!isfinite(x)||!isfinite(y)||!isfinite(time)) s->phase=MWEdgeRejected;
}
unsigned MWEdgeTouchHold(MWEdgeInteraction *s,double time) {
    if(!s || s->phase!=MWEdgePressed || !isfinite(time)) return MWEdgeActionNone;
    if(time-s->beganAt>=0.35 && s->maxDistance<12) {
        s->phase=MWEdgeHeld; return MWEdgeActionArmed;
    }
    return MWEdgeActionNone;
}
unsigned MWEdgeTouchUpdate(MWEdgeInteraction *s,double x,double y,double time) {
    if(!live(s)) return MWEdgeActionNone;
    if(!isfinite(x)||!isfinite(y)||!isfinite(time)) return MWEdgeTouchCancel(s);
    double dx=x-s->startX,dy=y-s->startY,distance=hypot(dx,dy);
    s->maxDistance=fmax(s->maxDistance,distance);
    if(s->phase==MWEdgeMoving) return MWEdgeActionMove;
    // Dragging is immediately available in every direction. Crossing the
    // threshold commits to moving, even if the finger returns to its origin.
    if(distance>=12) {
        s->phase=MWEdgeMoving; return MWEdgeActionMoveBegin|MWEdgeActionMove;
    }
    return MWEdgeTouchHold(s,time);
}
unsigned MWEdgeTouchEnd(MWEdgeInteraction *s,double x,double y,double time) {
    if(!live(s)) return MWEdgeActionNone;
    unsigned action=MWEdgeTouchUpdate(s,x,y,time);
    if(s->phase==MWEdgeMoving) action|=MWEdgeActionMoveEnd;
    else if(s->phase==MWEdgePressed || s->phase==MWEdgeHeld) {
        if(s->maxDistance<12) action|=MWEdgeActionTap;
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
