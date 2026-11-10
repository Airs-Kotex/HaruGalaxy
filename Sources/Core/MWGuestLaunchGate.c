// SPDX-License-Identifier: Apache-2.0
#include "MWGuestLaunchGate.h"
MWGuestLaunchAction MWGuestLaunchResolved(MWGuestLaunchGate *g,int pid) {
    if(!g || (g->phase!=MWGuestResolving && g->phase!=MWGuestRelaunching)) return MWGuestLaunchIgnore;
    if(pid<=1 || (g->phase==MWGuestRelaunching && g->originalPID==pid)) {
        g->phase=MWGuestLaunchFailed; return MWGuestLaunchFail;
    }
    if(g->phase==MWGuestResolving) { g->originalPID=pid; g->phase=MWGuestResetting; return MWGuestLaunchReset; }
    g->phase=MWGuestAttached; return MWGuestLaunchAttach;
}
MWGuestLaunchAction MWGuestLaunchResetFinished(MWGuestLaunchGate *g,bool success) {
    if(!g || g->phase!=MWGuestResetting) return MWGuestLaunchIgnore;
    g->phase=success ? MWGuestRelaunching : MWGuestLaunchFailed;
    return success ? MWGuestLaunchRelaunch : MWGuestLaunchFail;
}
void MWGuestLaunchCancel(MWGuestLaunchGate *g) { if(g) g->phase=MWGuestCancelled; }
bool MWGuestLaunchAllowsHandoff(const MWGuestLaunchGate *g,bool resetPending) {
    return g && !resetPending && g->phase==MWGuestAttached;
}
