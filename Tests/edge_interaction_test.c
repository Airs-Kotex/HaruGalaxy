#include "MWEdgeInteraction.h"
#include <assert.h>
#include <stdio.h>

static void tap_and_pull(void) {
    MWEdgeInteraction s={0};
    MWEdgeTouchBegin(&s,40,20,10,true,true);
    assert(MWEdgeTouchUpdate(&s,31,27,10.07)==MWEdgeActionNone);
    assert(MWEdgeTouchEnd(&s,28,29,10.12)&MWEdgeActionTap);
    assert(MWEdgeTouchEnd(&s,28,29,10.13)==MWEdgeActionNone);
    for(int right=0;right<2;right++) {
        MWEdgeTouchBegin(&s,100,100,20,right,true);
        double inward=right ? -22 : 22;
        assert(MWEdgeTouchUpdate(&s,100+inward,102,20.1)&MWEdgeActionPullReady);
        assert(MWEdgeTouchEnd(&s,100+inward,103,20.2)&MWEdgeActionPullOpen);
        assert(MWEdgeTouchHold(&s,20.5)==MWEdgeActionNone);
    }
    MWEdgeTouchBegin(&s,100,100,30,true,false);
    MWEdgeTouchUpdate(&s,70,100,30.1);
    assert(!(MWEdgeTouchEnd(&s,70,100,30.2)&MWEdgeActionPullOpen));
}

static void hold_move_and_cancel(void) {
    MWEdgeInteraction s={0};
    MWEdgeTouchBegin(&s,40,20,10,true,true);
    assert(MWEdgeTouchHold(&s,10.2)==MWEdgeActionNone);
    assert(MWEdgeTouchHold(&s,10.36)&MWEdgeActionArmed);
    assert(MWEdgeTouchHold(&s,10.4)==MWEdgeActionNone);
    // An imprecisely long tap must not silently swallow the attempt to open.
    assert(MWEdgeTouchEnd(&s,42,22,10.8)&MWEdgeActionTap);
    MWEdgeTouchBegin(&s,40,20,11,true,true);
    MWEdgeTouchHold(&s,11.36);
    unsigned release=MWEdgeTouchEnd(&s,32,27,11.7);
    assert((release&MWEdgeActionTap) && !(release&MWEdgeActionMoveBegin));
    MWEdgeTouchBegin(&s,40,20,20,true,true);
    MWEdgeTouchHold(&s,20.36);
    unsigned action=MWEdgeTouchUpdate(&s,40,32,20.4);
    assert((action&MWEdgeActionMoveBegin) && (action&MWEdgeActionMove));
    assert(MWEdgeTouchUpdate(&s,100,100,20.5)==MWEdgeActionMove);
    action=MWEdgeTouchEnd(&s,100,110,20.6);
    assert(action&MWEdgeActionMoveEnd);
    assert(!(action&(MWEdgeActionTap|MWEdgeActionPullOpen)));
    MWEdgeTouchBegin(&s,40,20,30,true,true);
    MWEdgeTouchHold(&s,30.36); MWEdgeTouchUpdate(&s,42,40,30.4);
    assert(MWEdgeTouchCancel(&s)&MWEdgeActionMoveCancel);
    assert(MWEdgeTouchEnd(&s,42,40,30.5)==MWEdgeActionNone);
    assert(MWEdgeTouchHold(&s,40)==MWEdgeActionNone);
}

static void rejected_gestures(void) {
    MWEdgeInteraction s={0};
    MWEdgeTouchBegin(&s,20,20,1,true,true);
    MWEdgeTouchUpdate(&s,20,60,1.1); // Vertical slide without holding cannot move.
    assert(MWEdgeTouchEnd(&s,20,20,1.2)==MWEdgeActionNone);
    MWEdgeTouchBegin(&s,20,20,2,true,true);
    MWEdgeTouchUpdate(&s,-10,20,2.1);
    assert(MWEdgeTouchEnd(&s,20,20,2.2)==MWEdgeActionNone); // Abandoned inward pull.
    MWEdgeTouchBegin(&s,20,20,3,true,true);
    MWEdgeTouchCancel(&s);
    assert(MWEdgeTouchEnd(&s,20,20,3.1)==MWEdgeActionNone);
    for(int drift=0;drift<=18;drift++) {
        MWEdgeTouchBegin(&s,40,40,5,true,true);
        unsigned action=MWEdgeTouchEnd(&s,40,40+drift,5.15);
        assert(action&MWEdgeActionTap);
    }
}

static void drift_before_hold(void) {
    MWEdgeInteraction s={0};
    MWEdgeTouchBegin(&s,100,100,10,true,true);
    MWEdgeTouchUpdate(&s,108,100,10.2);
    assert(MWEdgeTouchHold(&s,10.36)&MWEdgeActionArmed);
    // Small settling motion before the haptic must not count as a drag after it.
    assert(MWEdgeTouchUpdate(&s,108,100,10.4)==MWEdgeActionNone);
    assert(MWEdgeTouchUpdate(&s,111,100,10.5)==MWEdgeActionNone);
    assert(MWEdgeTouchEnd(&s,111,100,10.6)&MWEdgeActionTap);
    MWEdgeTouchBegin(&s,100,100,20,true,true);
    MWEdgeTouchUpdate(&s,108,100,20.2);
    MWEdgeTouchHold(&s,20.36);
    assert(MWEdgeTouchUpdate(&s,115,100,20.4)&MWEdgeActionMoveBegin);
    assert(MWEdgeTouchEnd(&s,140,100,20.5)&MWEdgeActionMoveEnd);
    // A delayed hold timer can be armed by tracking itself without moving yet.
    MWEdgeTouchBegin(&s,100,100,30,true,true);
    assert(MWEdgeTouchUpdate(&s,108,100,30.4)==MWEdgeActionArmed);
    assert(MWEdgeTouchEnd(&s,109,100,30.5)&MWEdgeActionTap);
}

int main(void) {
    tap_and_pull(); hold_move_and_cancel(); rejected_gestures(); drift_before_hold();
    puts("PASS: forgiving edge taps, two-sided inward pulls, hold-only wake, drag exclusivity and cancellation");
}
