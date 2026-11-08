#include "MWWindowModel.h"
#include <assert.h>
#include <math.h>
#include <stdio.h>

static void equal_rect(MWRect a, MWRect b) {
    assert(fabs(a.x-b.x)<0.001 && fabs(a.y-b.y)<0.001);
    assert(fabs(a.width-b.width)<0.001 && fabs(a.height-b.height)<0.001);
}

static void lifecycle(void) {
    MWWindowModel m=MWWindowCreate((MWRect){20,30,240,360});
    assert(!MWWindowApply(&m,MWEventMinimize));
    assert(MWWindowApply(&m,MWEventFailed));
    assert(MWWindowApply(&m,MWEventRetry));
    assert(MWWindowApply(&m,MWEventReady));
    assert(MWWindowApply(&m,MWEventMinimize));
    assert(!MWWindowApply(&m,MWEventReady));
    assert(MWWindowApply(&m,MWEventRestore));
    assert(MWWindowApply(&m,MWEventClose));
    for (int e=MWEventReady;e<=MWEventClose;e++) assert(!MWWindowApply(&m,(MWWindowEvent)e));
}

static void bounds(void) {
    MWRect viewport={10,50,370,730};
    equal_rect(MWConstrainRect((MWRect){-100,999,800,900},viewport),viewport);
    equal_rect(MWConstrainRect((MWRect){-100,-100,1,1},viewport),(MWRect){10,50,220,200});
    equal_rect(MWConstrainRect((MWRect){500,500,400,400},(MWRect){0,0,100,90}),(MWRect){0,0,100,90});
    MWRect sane=MWConstrainRect((MWRect){NAN,INFINITY,-INFINITY,NAN},viewport);
    assert(isfinite(sane.x) && isfinite(sane.y) && isfinite(sane.width) && isfinite(sane.height));
    for (int i=0;i<2000;i++) {
        MWRect r=MWConstrainRect((MWRect){i-1000,1000-i,(i%700)-300,(i%900)-400},viewport);
        assert(r.x>=viewport.x && r.y>=viewport.y);
        assert(r.width>=220 && r.height>=200);
        assert(r.x+r.width<=viewport.x+viewport.width+0.001);
        assert(r.y+r.height<=viewport.y+viewport.height+0.001);
    }
}

static void maximize_restore(void) {
    MWRect viewport={10,50,370,730}, original={30,80,240,360};
    MWWindowModel m=MWWindowCreate(original);
    assert(!MWWindowToggleMaximize(&m,viewport));
    assert(MWWindowApply(&m,MWEventReady));
    assert(MWWindowToggleMaximize(&m,viewport));
    equal_rect(m.frame,viewport);
    assert(MWWindowApply(&m,MWEventMinimize));
    assert(m.maximized);
    assert(MWWindowApply(&m,MWEventRestore));
    assert(MWWindowToggleMaximize(&m,viewport));
    equal_rect(m.frame,original);
    assert(MWWindowToggleMaximize(&m,viewport));
    MWRect rotated={30,10,730,370};
    MWWindowReflow(&m,rotated);
    equal_rect(m.frame,rotated);
    assert(MWWindowToggleMaximize(&m,rotated));
    equal_rect(m.frame,MWConstrainRect(original,rotated));
}

int main(void) {
    lifecycle(); bounds(); maximize_restore();
    puts("PASS: lifecycle, invalid geometry, 2000 boundary cases, maximize/restore and rotation");
    return 0;
}
