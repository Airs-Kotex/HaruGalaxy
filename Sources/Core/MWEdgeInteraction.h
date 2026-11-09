// SPDX-License-Identifier: Apache-2.0
#pragma once
#include <stdbool.h>

typedef enum {
    MWEdgeIdle, MWEdgePressed, MWEdgeHeld, MWEdgeMoving,
    MWEdgePulled, MWEdgeRejected, MWEdgeFinished
} MWEdgeTouchPhase;
typedef enum {
    MWEdgeActionNone=0, MWEdgeActionArmed=1<<0,
    MWEdgeActionMoveBegin=1<<1, MWEdgeActionMove=1<<2,
    MWEdgeActionMoveEnd=1<<3, MWEdgeActionMoveCancel=1<<4,
    MWEdgeActionTap=1<<5, MWEdgeActionPullReady=1<<6, MWEdgeActionPullOpen=1<<7
} MWEdgeTouchAction;
typedef struct {
    MWEdgeTouchPhase phase;
    double startX, startY, lastX, lastY, heldX, heldY, beganAt, maxDistance;
    bool right, allowsPull;
} MWEdgeInteraction;

void MWEdgeTouchBegin(MWEdgeInteraction *touch,double x,double y,double time,bool right,bool allowsPull);
unsigned MWEdgeTouchUpdate(MWEdgeInteraction *touch,double x,double y,double time);
unsigned MWEdgeTouchHold(MWEdgeInteraction *touch,double time);
unsigned MWEdgeTouchEnd(MWEdgeInteraction *touch,double x,double y,double time);
unsigned MWEdgeTouchCancel(MWEdgeInteraction *touch);
