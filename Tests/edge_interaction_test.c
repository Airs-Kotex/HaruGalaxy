#include "MWEdgeInteraction.h"
#include <assert.h>
#include <stdio.h>

static void tap_and_pull(void) {
    MWEdgeInteraction s={0};
    MWEdgeTouchBegin(&s,40,20,10);
    assert(MWEdgeTouchUpdate(&s,35,23,10.07)==MWEdgeActionNone);
    assert(MWEdgeTouchEnd(&s,34,24,10.12)&MWEdgeActionTap);
    assert(MWEdgeTouchEnd(&s,34,24,10.13)==MWEdgeActionNone);
    for(int right=0;right<2;right++) {
        MWEdgeTouchBegin(&s,100,100,20);
        double inward=right ? -22 : 22;
        assert(MWEdgeTouchUpdate(&s,100+inward,102,20.1)&MWEdgeActionMoveBegin);
        assert(MWEdgeTouchEnd(&s,100+inward,103,20.2)&MWEdgeActionMoveEnd);
        assert(MWEdgeTouchHold(&s,20.5)==MWEdgeActionNone);
    }
    MWEdgeTouchBegin(&s,100,100,30);
    assert(MWEdgeTouchUpdate(&s,70,100,30.1)&MWEdgeActionMoveBegin);
    assert(MWEdgeTouchEnd(&s,70,100,30.2)&MWEdgeActionMoveEnd);
}

static void hold_move_and_cancel(void) {
    MWEdgeInteraction s={0};
    MWEdgeTouchBegin(&s,40,20,10);
    assert(MWEdgeTouchHold(&s,10.2)==MWEdgeActionNone);
    assert(MWEdgeTouchHold(&s,10.36)&MWEdgeActionArmed);
    assert(MWEdgeTouchHold(&s,10.4)==MWEdgeActionNone);
    // An imprecisely long tap must not silently swallow the attempt to open.
    assert(MWEdgeTouchEnd(&s,42,22,10.8)&MWEdgeActionTap);
    MWEdgeTouchBegin(&s,40,20,11);
    MWEdgeTouchHold(&s,11.36);
    unsigned release=MWEdgeTouchEnd(&s,32,27,11.7);
    assert((release&MWEdgeActionTap) && !(release&MWEdgeActionMoveBegin));
    MWEdgeTouchBegin(&s,40,20,20);
    MWEdgeTouchHold(&s,20.36);
    unsigned action=MWEdgeTouchUpdate(&s,40,32,20.4);
    assert((action&MWEdgeActionMoveBegin) && (action&MWEdgeActionMove));
    assert(MWEdgeTouchUpdate(&s,100,100,20.5)==MWEdgeActionMove);
    action=MWEdgeTouchEnd(&s,100,110,20.6);
    assert(action&MWEdgeActionMoveEnd);
    assert(!(action&(MWEdgeActionTap)));
    MWEdgeTouchBegin(&s,40,20,30);
    MWEdgeTouchHold(&s,30.36); MWEdgeTouchUpdate(&s,42,40,30.4);
    assert(MWEdgeTouchCancel(&s)&MWEdgeActionMoveCancel);
    assert(MWEdgeTouchEnd(&s,42,40,30.5)==MWEdgeActionNone);
    assert(MWEdgeTouchHold(&s,40)==MWEdgeActionNone);
}

static void rejected_gestures(void) {
    MWEdgeInteraction s={0};
    MWEdgeTouchBegin(&s,20,20,1);
    assert(MWEdgeTouchUpdate(&s,20,60,1.1)&MWEdgeActionMoveBegin);
    MWEdgeTouchCancel(&s);
    assert(MWEdgeTouchEnd(&s,20,20,1.2)==MWEdgeActionNone);
    MWEdgeTouchBegin(&s,20,20,2);
    MWEdgeTouchUpdate(&s,-10,20,2.1);
    assert(MWEdgeTouchEnd(&s,20,20,2.2)&MWEdgeActionMoveEnd); // Moving back never opens.
    MWEdgeTouchBegin(&s,20,20,3);
    MWEdgeTouchCancel(&s);
    assert(MWEdgeTouchEnd(&s,20,20,3.1)==MWEdgeActionNone);
    for(int drift=0;drift<12;drift++) {
        MWEdgeTouchBegin(&s,40,40,5);
        unsigned action=MWEdgeTouchEnd(&s,40,40+drift,5.15);
        assert(action&MWEdgeActionTap);
    }
}

static void drift_before_hold(void) {
    MWEdgeInteraction s={0};
    MWEdgeTouchBegin(&s,100,100,10);
    MWEdgeTouchUpdate(&s,108,100,10.2);
    assert(MWEdgeTouchHold(&s,10.36)&MWEdgeActionArmed);
    // Small settling motion before the haptic must not count as a drag after it.
    assert(MWEdgeTouchUpdate(&s,108,100,10.4)==MWEdgeActionNone);
    assert(MWEdgeTouchUpdate(&s,111,100,10.5)==MWEdgeActionNone);
    assert(MWEdgeTouchEnd(&s,111,100,10.6)&MWEdgeActionTap);
    MWEdgeTouchBegin(&s,100,100,20);
    MWEdgeTouchUpdate(&s,108,100,20.2);
    MWEdgeTouchHold(&s,20.36);
    assert(MWEdgeTouchUpdate(&s,121,100,20.4)&MWEdgeActionMoveBegin);
    assert(MWEdgeTouchEnd(&s,140,100,20.5)&MWEdgeActionMoveEnd);
    // A delayed hold timer can be armed by tracking itself without moving yet.
    MWEdgeTouchBegin(&s,100,100,30);
    assert(MWEdgeTouchUpdate(&s,108,100,30.4)==MWEdgeActionArmed);
    assert(MWEdgeTouchEnd(&s,109,100,30.5)&MWEdgeActionTap);
}

int main(void) {
    tap_and_pull(); hold_move_and_cancel(); rejected_gestures(); drift_before_hold();
    puts("PASS: direct entry drags in both directions, small-drift taps, stationary hold and cancellation");
}
