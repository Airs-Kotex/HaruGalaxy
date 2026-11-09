// SPDX-License-Identifier: Apache-2.0
#pragma once
#include <stdbool.h>
#include <stdint.h>

typedef enum { MWSearchIdle, MWSearchWaiting, MWSearchPresenting, MWSearchActive, MWSearchFailed } MWSearchPhase;
typedef enum { MWSearchIgnore, MWSearchWait, MWSearchActivateScene, MWSearchPresent, MWSearchAbort } MWSearchAction;
typedef struct {
    uint64_t generation;
    MWSearchPhase phase;
    double deadline, sceneFallbackAt;
    bool sceneRequested;
} MWSearchHandoff;

uint64_t MWSearchHandoffBegin(MWSearchHandoff *s,double now);
bool MWSearchHandoffCurrent(const MWSearchHandoff *s,uint64_t generation);
void MWSearchHandoffLaunchResult(MWSearchHandoff *s,uint64_t generation,bool accepted,double now);
MWSearchAction MWSearchHandoffObserve(MWSearchHandoff *s,uint64_t generation,double now,bool foreground,bool presenterReady);
bool MWSearchHandoffPresented(MWSearchHandoff *s,uint64_t generation);
void MWSearchHandoffFinish(MWSearchHandoff *s);
