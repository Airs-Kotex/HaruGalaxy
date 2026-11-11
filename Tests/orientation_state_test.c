// SPDX-License-Identifier: Apache-2.0
#include "MWOrientationState.h"
#include <assert.h>
#include <stdio.h>

static void testGuestEcho(void) {
    const int workspace[]={1,3,4,1,3};
    const unsigned declared[]={26,24,2,0};
    const int expected[][5]={{1,3,4,1,3},{3,3,4,4,3},{1,1,1,1,1},{1,3,4,1,3}};
    // The client applies each request and echoes it with mask zero. Check the
    // complete feedback loop, including a delayed reply during rotation.
    for(unsigned app=0;app<4;app++) for(int delayed=0;delayed<=1;delayed++) {
        MWGuestOrientationState guest={0};
        int previous=1,client=0;
        for(unsigned i=0;i<5;i++) {
            unsigned mask=MWGuestRetainOrientationMask(&guest,0,client);
            int requested=MWGuestOrientation(workspace[i],declared[app],mask,client,previous);
            assert(requested==expected[app][i]);
            previous=requested;
            if(delayed) {
                mask=MWGuestRetainOrientationMask(&guest,0,client);
                assert(MWGuestOrientation(workspace[i],declared[app],mask,client,previous)==requested);
            }
            client=requested;
            mask=MWGuestRetainOrientationMask(&guest,0,client);
            assert(MWGuestOrientation(workspace[i],declared[app],mask,client,previous)==requested);
        }
    }
}

static void testRetainedGuestMask(void) {
    MWGuestOrientationState guest={0};
    int previous=1;
    // A new nonzero landscape mask may arrive before the client rotates.
    assert(MWGuestRetainOrientationMask(&guest,24,1)==24);
    for(unsigned i=0;i<3;i++) {
        unsigned mask=MWGuestRetainOrientationMask(&guest,0,1);
        assert(mask==24);
        previous=MWGuestOrientation(1,2,mask,1,previous);
        assert(previous==3);
    }
    // app#3 declares portrait but reports landscape with alternating 24/0.
    const unsigned sequence[]={24,0,24,0,0,24,0,24};
    for(unsigned i=0;i<sizeof(sequence)/sizeof(sequence[0]);i++) {
        unsigned mask=MWGuestRetainOrientationMask(&guest,sequence[i],3);
        assert(mask==24);
        int orientation=MWGuestOrientation(1,2,mask,3,previous);
        assert(orientation==3 && orientation==previous);
        previous=orientation;
    }
    // Missing getters/invalid values do not revoke a confirmed runtime mask.
    for(int invalid=-1;invalid<=7;invalid++) if(!MWOrientationIsValid(invalid)) {
        assert(MWGuestRetainOrientationMask(&guest,1u<<20,invalid)==24);
        assert(MWGuestOrientation(1,2,guest.retainedMask,invalid,previous)==3);
    }
    // Inferred fullscreen-exit risk: after reporting landscape, the client
    // returns to portrait and reports only zero. Retire the conflicting cache.
    assert(MWGuestRetainOrientationMask(&guest,0,1)==0);
    for(int workspace=1;workspace<=4;workspace++) {
        assert(MWGuestRetainOrientationMask(&guest,0,1)==0);
        assert(MWGuestOrientation(workspace,2,guest.retainedMask,1,previous)==1);
    }
    // Re-enter fullscreen. The new mask wins before the portrait echo changes.
    assert(MWGuestRetainOrientationMask(&guest,24,1)==24);
    assert(MWGuestRetainOrientationMask(&guest,0,1)==24);
    assert(MWGuestRetainOrientationMask(&guest,0,3)==24);
    assert(MWGuestOrientation(1,2,guest.retainedMask,3,1)==3);
    // An explicit nonzero mask wins and starts a fresh confirmation cycle,
    // including a repeated value with a direction that has not caught up.
    assert(MWGuestRetainOrientationMask(&guest,2,3)==2);
    assert(MWGuestRetainOrientationMask(&guest,0,3)==2);
    assert(MWGuestOrientation(3,24,guest.retainedMask,3,3)==1);
    assert(MWGuestRetainOrientationMask(&guest,0,1)==2);
    assert(MWGuestRetainOrientationMask(&guest,2,3)==2); // fresh nonzero mask
    assert(MWGuestRetainOrientationMask(&guest,0,3)==2); // prior confirmation cannot retire it
    assert(MWGuestRetainOrientationMask(&guest,0,1)==2); // this cycle now matched
    assert(MWGuestRetainOrientationMask(&guest,0,3)==0);
    assert(MWGuestOrientation(1,24,guest.retainedMask,3,1)==3);
    // A separate guest starts without cached constraints or confirmation.
    MWGuestOrientationState another={0};
    assert(MWGuestRetainOrientationMask(&another,0,1)==0);
    assert(MWGuestOrientation(1,24,another.retainedMask,1,1)==3);
    // Check cache expiry in all four directions, including repeated snapshots.
    for(int first=1;first<=4;first++) for(int next=1;next<=4;next++) if(first!=next) {
        MWGuestOrientationState transition={0};
        unsigned initial=1u<<first,declared=1u<<next;
        assert(MWGuestRetainOrientationMask(&transition,initial,first)==initial);
        assert(MWGuestOrientation(next,declared,initial,first,next)==first);
        assert(MWGuestRetainOrientationMask(&transition,0,next)==0);
        assert(MWGuestRetainOrientationMask(&transition,0,next)==0);
        assert(MWGuestOrientation(first,declared,transition.retainedMask,next,first)==next);
    }
}

static void testGuestMaskRenewal(void) {
    // A reasserted 24 must behave the same whether the old confirmed mask was
    // identical (24) or different (8). Both clients still report portrait.
    const unsigned priorMasks[]={24,8};
    for(unsigned i=0;i<2;i++) {
        MWGuestOrientationState guest={0};
        assert(MWGuestRetainOrientationMask(&guest,priorMasks[i],3)==priorMasks[i]);
        assert(MWGuestRetainOrientationMask(&guest,24,1)==24);
        for(unsigned echo=0;echo<3;echo++) {
            assert(MWGuestRetainOrientationMask(&guest,0,1)==24);
            assert(MWGuestOrientation(1,2,guest.retainedMask,1,3)==3);
        }
        // For prior mask 24, the very same observations could mean an exit
        // whose direction changed before its mask. The two scalars cannot
        // distinguish it from renewal. Prefer the fresh mask; an explicit
        // portrait constraint can resolve this otherwise ambiguous exit.
        MWGuestOrientationState explicitExit=guest;
        assert(MWGuestRetainOrientationMask(&explicitExit,2,1)==2);
        assert(MWGuestRetainOrientationMask(&explicitExit,0,1)==2);
        assert(MWGuestOrientation(1,2,explicitExit.retainedMask,1,3)==1);
        assert(MWGuestRetainOrientationMask(&guest,0,3)==24);
        assert(MWGuestRetainOrientationMask(&guest,0,1)==0);
        assert(MWGuestOrientation(1,2,guest.retainedMask,1,3)==1);
    }
    // Repeat each snapshot to cover unrelated client-setting callbacks. The
    // reducer must remain idempotent across all supported masks/directions.
    for(unsigned retained=0;retained<=30;retained+=2)
        for(int confirmed=0;confirmed<=1;confirmed++)
            for(unsigned mask=0;mask<32;mask++)
                for(int client=-1;client<=7;client++) {
                    MWGuestOrientationState guest={retained,confirmed!=0};
                    unsigned once=MWGuestRetainOrientationMask(&guest,mask,client);
                    bool onceConfirmed=guest.maskConfirmed;
                    assert(MWGuestRetainOrientationMask(&guest,mask,client)==once);
                    assert(guest.maskConfirmed==onceConfirmed);
                }
}

static void testQueuedGuestObservations(void) {
    // Model delayed main-queue consumption of scalar callback snapshots. This
    // checks ordered state reduction, not actual FrontBoard dispatch behavior.
    typedef struct { unsigned mask; int client; } Observation;
    const Observation events[]={{24,1},{0,3},{0,1}};
    const unsigned expectedMasks[]={24,24,0};
    const int expectedDirections[]={3,3,1};
    for(unsigned pending=0;pending<=3;pending++) {
        Observation queue[3];
        MWGuestOrientationState guest={0};
        unsigned consumed=0;
        int previous=1;
        for(unsigned event=0;event<3;event++) {
            queue[event]=events[event];
            if(event<pending) continue;
            while(consumed<=event) {
                Observation snapshot=queue[consumed];
                unsigned mask=MWGuestRetainOrientationMask(&guest,snapshot.mask,snapshot.client);
                assert(mask==expectedMasks[consumed]);
                previous=MWGuestOrientation(1,2,mask,snapshot.client,previous);
                assert(previous==expectedDirections[consumed]);
                consumed++;
            }
        }
        while(consumed<3) {
            Observation snapshot=queue[consumed];
            unsigned mask=MWGuestRetainOrientationMask(&guest,snapshot.mask,snapshot.client);
            assert(mask==expectedMasks[consumed]);
            previous=MWGuestOrientation(1,2,mask,snapshot.client,previous);
            assert(previous==expectedDirections[consumed]);
            consumed++;
        }
        assert(guest.retainedMask==0 && previous==1);
    }
}

int main(void) {
    MWOrientationState state={0};
    assert(MWWorkspaceOrientation(&state,true,0)==1);
    assert(MWWorkspaceOrientation(&state,true,4)==4);
    uint64_t first=MWOrientationSetActive(&state,true);
    assert(MWOrientationSetActive(&state,true)==first);
    assert(MWOrientationObservePhysical(&state,first,1));
    // Ordinary and floating workspaces share source arbitration. A host enum
    // alone does not disable gravity-following when system rotation is locked.
    assert(MWWorkspaceOrientation(&state,false,3)==1);
    // System rotation reaches a floating workspace even with thousands of
    // unchanged portrait sensor samples.
    assert(MWOrientationObserveSystem(&state,first,3));
    for(unsigned i=0;i<8000;i++) assert(!MWOrientationObservePhysical(&state,first,1));
    assert(MWWorkspaceOrientation(&state,true,1)==3);
    assert(MWWorkspaceOrientation(&state,false,1)==3);
    assert(MWWorkspaceQuarterTurns(3,MWWorkspaceOrientation(&state,false,3))==0);
    assert(state.source==MWOrientationSourceSystem);
    assert(MWWorkspaceQuarterTurns(1,state.orientation)==1);
    // Physical rotation remains usable when the underlying app stays portrait.
    assert(MWOrientationObservePhysical(&state,first,4));
    assert(!MWOrientationObserveSystem(&state,first,3));
    assert(MWWorkspaceOrientation(&state,true,1)==4);
    assert(state.source==MWOrientationSourcePhysical);
    assert(MWOrientationObserveSystem(&state,first,2));
    for(int invalid=-1;invalid<=7;invalid++) if(!MWOrientationIsValid(invalid)) {
        assert(!MWOrientationObserveSystem(&state,first,invalid));
        assert(!MWOrientationObservePhysical(&state,first,invalid));
        assert(state.orientation==2);
    }
    MWOrientationSetActive(&state,false);
    assert(!MWOrientationObserveSystem(&state,first,1));
    assert(!MWOrientationObservePhysical(&state,state.generation,1));
    assert(state.orientation==2);
    uint64_t resumed=MWOrientationSetActive(&state,true);
    assert(resumed!=first);
    assert(!MWOrientationObserveSystem(&state,first,4));
    assert(!MWOrientationObservePhysical(&state,first,4));
    assert(MWOrientationObserveSystem(&state,resumed,3));
    assert(MWOrientationObservePhysical(&state,resumed,1));
    assert(state.orientation==1); // first physical observation after resume
    assert(MWOrientationObservePhysical(&state,resumed,4));
    MWOrientationSetActive(&state,false);
    resumed=MWOrientationSetActive(&state,true);
    // Optional observer absent/invalid: physical input remains functional.
    assert(!MWOrientationObserveSystem(&state,resumed,0));
    assert(MWOrientationObservePhysical(&state,resumed,1));
    assert(MWOrientationObservePhysical(&state,resumed,3));
    MWOrientationState locked={0};
    uint64_t lockedGeneration=MWOrientationSetActive(&locked,true);
    assert(MWOrientationObserveSystem(&locked,lockedGeneration,1));
    assert(MWOrientationObservePhysical(&locked,lockedGeneration,3));
    assert(MWWorkspaceOrientation(&locked,true,1)==3);
    assert(MWWorkspaceOrientation(&locked,false,1)==3); // non-floating lock
    assert(!MWOrientationObserveSystem(&locked,lockedGeneration,1));
    assert(!MWOrientationObservePhysical(&locked,lockedGeneration,0)); // flat
    assert(MWWorkspaceOrientation(&locked,false,1)==3);
    assert(MWOrientationObservePhysical(&locked,lockedGeneration,4));
    assert(MWWorkspaceOrientation(&locked,false,1)==4);
    assert(MWOrientationObserveSystem(&locked,lockedGeneration,4)==false);
    assert(MWWorkspaceQuarterTurns(4,MWWorkspaceOrientation(&locked,false,4))==0);
    // Activation/resume: stale UIDevice must not undo the current system
    // direction. Exercise both call orders and the foreground/background gate.
    for(int foreground=0;foreground<=1;foreground++) for(int systemFirst=0;systemFirst<=1;systemFirst++) {
        MWOrientationState activation={0};
        uint64_t gen=MWOrientationSetActive(&activation,true);
        assert(MWOrientationObservePhysical(&activation,gen,1));
        MWOrientationSetActive(&activation,false);
        uint64_t active=MWOrientationSetActive(&activation,true);
        assert(!MWOrientationObserveDevice(&activation,gen,2,true,false));
        assert(!MWOrientationObserveSystem(&activation,gen,2));
        if(systemFirst) assert(MWOrientationObserveSystem(&activation,active,3));
        MWOrientationObserveDevice(&activation,active,1,foreground,true);
        if(!systemFirst) assert(MWOrientationObserveSystem(&activation,active,3));
        assert(MWWorkspaceOrientation(&activation,true,1)==3);
        assert(MWWorkspaceOrientation(&activation,false,1)==3);
        assert(activation.source==MWOrientationSourceSystem);
        // No gravity classification while flat must preserve system direction.
        assert(!MWOrientationObservePhysical(&activation,active,0));
        assert(!MWOrientationObserveDevice(&activation,active,1,false,true));
        assert(activation.orientation==3);
        // Fresh measured gravity remains authoritative, even if numerically
        // identical to the earlier UIDevice cache. The two have distinct state.
        assert(MWOrientationObservePhysical(&activation,active,1));
        assert(activation.source==MWOrientationSourcePhysical);
        assert(!MWOrientationObserveDevice(&activation,active,2,true,true));
        assert(activation.orientation==1);
    }
    MWOrientationState fallback={0};
    uint64_t fallbackGeneration=MWOrientationSetActive(&fallback,true);
    assert(!MWOrientationObserveDevice(&fallback,fallbackGeneration,3,false,true));
    assert(MWOrientationObserveDevice(&fallback,fallbackGeneration,3,true,true));
    assert(MWWorkspaceOrientation(&fallback,false,1)==3); // no observer/motion
    assert(MWOrientationObserveDevice(&fallback,fallbackGeneration,4,true,false));
    // A visible floating workspace is active even when the ordinary App is in
    // the background. With no recent motion, real notifications must rotate it.
    assert(MWOrientationObserveDevice(&fallback,fallbackGeneration,3,false,false));
    assert(MWWorkspaceOrientation(&fallback,true,1)==3);
    assert(!MWOrientationObserveDevice(&fallback,fallbackGeneration,1,false,true));
    assert(!MWOrientationObserveDevice(&fallback,fallbackGeneration,0,false,false));
    assert(!MWOrientationObserveDevice(&fallback,fallbackGeneration,3,false,false));
    assert(MWOrientationObserveDevice(&fallback,fallbackGeneration,4,false,false));
    MWOrientationSetActive(&fallback,false);
    assert(!MWOrientationObserveDevice(&fallback,fallback.generation,1,false,false));
    uint64_t newGeneration=MWOrientationSetActive(&fallback,true);
    assert(!MWOrientationObserveDevice(&fallback,fallbackGeneration,1,false,false));
    assert(MWOrientationObserveDevice(&fallback,newGeneration,3,false,false));
    const int turns[4][4]={{0,2,1,-1},{-2,0,-1,1},{-1,1,0,-2},{1,-1,2,0}};
    for(int host=1;host<=4;host++) for(int target=1;target<=4;target++) {
        assert(MWWorkspaceQuarterTurns(host,target)==turns[host-1][target-1]);
        bool swapsAxes=(host<=2)!=(target<=2);
        assert((MWWorkspaceQuarterTurns(host,target)%2!=0)==swapsAxes);
    }
    // Device evidence: host portrait, guest reports landscape + mask 24.
    assert(MWGuestOrientation(1,24,24,3,1)==3);
    assert(MWGuestOrientation(1,24,0,0,1)==3); // before first client reply
    assert(MWGuestOrientation(1,24,24,4,3)==4);
    assert(MWGuestOrientation(4,24,24,3,3)==4); // supported physical rotation
    assert(MWGuestOrientation(3,2,2,1,3)==1); // portrait-only app
    assert(MWGuestOrientation(1,2,24,4,1)==4); // current client mask wins
    assert(MWGuestOrientation(3,24,2,1,3)==1);
    assert(MWGuestOrientation(3,30,0,1,1)==3); // a client echo must not lock rotation
    assert(MWGuestOrientation(4,0,0,1,1)==4);
    assert(MWGuestOrientation(1,2,0,3,3)==1); // no runtime constraint: use declaration
    assert(MWGuestOrientation(1,2,0,4,1)==1);
    assert(MWGuestOrientation(1,16,0,0,0)==4);
    assert(MWGuestOrientation(3,4,0,0,0)==2);
    assert(MWGuestOrientation(0,0,0,0,4)==4);
    for(unsigned mask=1;mask<32;mask++) if(mask & 30)
        for(int host=1;host<=4;host++) {
            int result=MWGuestOrientation(host,mask,0,0,0);
            assert(MWOrientationIsValid(result) && (mask & (1u<<result)));
        }
    assert(MWGuestOrientation(1,24,0,1,3)==3); // portrait echo cannot defeat landscape declaration
    testGuestEcho();
    testRetainedGuestMask();
    testGuestMaskRenewal();
    testQueuedGuestObservations();
    puts("PASS: orientation activation, locked workspaces, guest echo loops, mask renewal/expiry and queued observation order");
}
