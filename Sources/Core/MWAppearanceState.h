// SPDX-License-Identifier: Apache-2.0
#pragma once
#include <stdbool.h>
#include <stdint.h>

typedef struct {
    int systemStyle; // UIKit:0 unspecified,1 light,2 dark
    uint64_t appliedRevision;
} MWAppearanceState;

// Call on the UI thread. Assign revisions at observation time, before queueing
// notification delivery. Only a current ordinary-scene snapshot is a fallback;
// a background scene or an overridden floating window is not a system source.
bool MWAppearanceObserve(MWAppearanceState *state,uint64_t revision,int systemStyle,int sceneStyle,bool sceneIsCurrent);
int MWAppearanceOverride(const MWAppearanceState *state,int preference);
