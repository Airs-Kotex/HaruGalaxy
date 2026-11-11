// SPDX-License-Identifier: Apache-2.0
#include "MWAppearanceState.h"

static bool valid(int style) { return style==1 || style==2; }
bool MWAppearanceObserve(MWAppearanceState *state,uint64_t revision,int systemStyle,int sceneStyle,bool sceneIsCurrent) {
    if(revision<=state->appliedRevision) return false;
    int style=valid(systemStyle) ? systemStyle : (sceneIsCurrent && valid(sceneStyle) ? sceneStyle : 0);
    if(!style) return false;
    bool changed=state->systemStyle!=style;
    state->systemStyle=style;
    // Even an unchanged newer snapshot supersedes a queued older transition.
    state->appliedRevision=revision;
    return changed;
}
int MWAppearanceOverride(const MWAppearanceState *state,int preference) {
    return valid(preference) ? preference : state->systemStyle;
}
