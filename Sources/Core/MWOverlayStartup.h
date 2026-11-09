// SPDX-License-Identifier: Apache-2.0
#pragma once
#include <stdbool.h>
#include <stdint.h>

typedef enum { MWOverlayStartupIdle, MWOverlayStartupWaiting, MWOverlayStartupReady,
    MWOverlayStartupFailed, MWOverlayStartupCancelled } MWOverlayStartupPhase;
typedef enum { MWOverlayRootPending, MWOverlayRootReady, MWOverlayRootRejected } MWOverlayRootResult;
typedef enum { MWOverlayStartupIgnore, MWOverlayStartupWait,
    MWOverlayStartupComplete, MWOverlayStartupAbort } MWOverlayStartupAction;
typedef struct {
    uint64_t generation;
    MWOverlayStartupPhase phase;
    double deadline;
    bool sceneAdded, windowConnected, rootAttached;
} MWOverlayStartup;

uint64_t MWOverlayStartupBegin(MWOverlayStartup *startup, double now, double timeout);
void MWOverlayStartupSceneAdded(MWOverlayStartup *startup, uint64_t generation);
void MWOverlayStartupWindowConnected(MWOverlayStartup *startup, uint64_t generation);
bool MWOverlayStartupCanProbe(const MWOverlayStartup *startup, uint64_t generation);
MWOverlayStartupAction MWOverlayStartupObserve(MWOverlayStartup *startup, uint64_t generation, double now, MWOverlayRootResult result);
void MWOverlayStartupCancel(MWOverlayStartup *startup);
