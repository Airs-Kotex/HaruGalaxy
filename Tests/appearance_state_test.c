// SPDX-License-Identifier: Apache-2.0
#include "MWAppearanceState.h"
#include <assert.h>
#include <stdio.h>

static void reconnect_and_preferences(void) {
    MWAppearanceState state={0};
    assert(MWAppearanceOverride(&state,0)==0);
    assert(MWAppearanceObserve(&state,1,0,1,true));
    assert(MWAppearanceOverride(&state,0)==1);
    // The getter is unavailable, but the replacement/resumed ordinary scene
    // has a fresh dark trait. A nonzero old cache must not disable fallback.
    assert(MWAppearanceObserve(&state,2,0,2,true));
    assert(state.systemStyle==2 && state.appliedRevision==2);
    assert(MWAppearanceOverride(&state,2)==2);
    assert(MWAppearanceOverride(&state,0)==2); // manual dark -> automatic
    assert(MWAppearanceOverride(&state,1)==1);
    assert(MWAppearanceOverride(&state,0)==2); // manual light -> automatic
    // Cache can change during a manual override; the preference still wins.
    assert(MWAppearanceObserve(&state,3,1,2,false));
    assert(MWAppearanceOverride(&state,2)==2);
    assert(MWAppearanceOverride(&state,0)==1);
    // A stale background trait or floating-window override is not a fallback.
    assert(!MWAppearanceObserve(&state,4,0,2,false));
    assert(state.systemStyle==1 && state.appliedRevision==3);
    assert(MWAppearanceObserve(&state,5,0,2,true));
    assert(MWAppearanceOverride(&state,0)==2);
}
static void queued_observations(void) {
    MWAppearanceState state={0};
    assert(MWAppearanceObserve(&state,1,1,0,false));
    // Old light event2 waits in the main queue; newer scene snapshot3 is dark.
    assert(MWAppearanceObserve(&state,3,0,2,true));
    assert(!MWAppearanceObserve(&state,2,1,0,false));
    assert(MWAppearanceOverride(&state,0)==2 && state.appliedRevision==3);
    // Even a numerically unchanged snapshot must retire older queued events.
    assert(!MWAppearanceObserve(&state,5,2,0,false));
    assert(!MWAppearanceObserve(&state,4,1,0,false));
    assert(state.systemStyle==2 && state.appliedRevision==5);
    assert(!MWAppearanceObserve(&state,5,1,0,false));
    assert(MWAppearanceObserve(&state,6,1,0,false));
    // Consume all6 permutations of two notifications and a scene fallback.
    // This is an ordering check for the production reducer, not OS scheduling.
    for(int a=0;a<3;a++) for(int b=0;b<3;b++) for(int c=0;c<3;c++) {
        if(a==b || b==c || a==c) continue;
        MWAppearanceState next={0};
        int order[]={a,b,c},styles[]={1,2,1};
        for(int i=0;i<3;i++) {
            int event=order[i];
            MWAppearanceObserve(&next,(uint64_t)event+1,event==2 ? 0 : styles[event],styles[event],event==2);
        }
        assert(next.systemStyle==1 && next.appliedRevision==3);
    }
}
static void unavailable_sources(void) {
    for(int system=-1;system<=4;system++) for(int scene=-1;scene<=4;scene++) for(int current=0;current<=1;current++) {
        MWAppearanceState state={0};
        MWAppearanceObserve(&state,1,system,scene,current);
        if(system==1 || system==2) assert(state.systemStyle==system);
        else if(current && (scene==1 || scene==2)) assert(state.systemStyle==scene);
        else assert(state.systemStyle==0 && state.appliedRevision==0);
        assert(MWAppearanceOverride(&state,1)==1 && MWAppearanceOverride(&state,2)==2);
        assert(MWAppearanceOverride(&state,0)==state.systemStyle);
    }
    MWAppearanceState state={0};
    assert(MWAppearanceObserve(&state,1,2,1,true)); // valid system snapshot wins
    assert(!MWAppearanceObserve(&state,2,0,0,true));
    assert(!MWAppearanceObserve(&state,3,-1,3,true));
    assert(!MWAppearanceObserve(&state,0,1,1,true));
    assert(state.systemStyle==2 && state.appliedRevision==1);
}
int main(void) {
    reconnect_and_preferences(); queued_observations(); unavailable_sources();
    puts("PASS: appearance reconnect/resume fallback, manual-to-auto, stale-event ordering and unavailable sources");
    return 0;
}
