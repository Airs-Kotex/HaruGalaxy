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
    assert(fabs(m.frame.width/(m.frame.height-MWTitleHeight)-m.aspectRatio)<0.001);
    assert(MWWindowApply(&m,MWEventMinimize));
    assert(m.maximized);
    assert(MWWindowApply(&m,MWEventRestore));
    assert(MWWindowToggleMaximize(&m,viewport));
    equal_rect(m.frame,original);
    assert(MWWindowToggleMaximize(&m,viewport));
    MWRect rotated={30,10,730,370};
    MWWindowReflow(&m,rotated);
    assert(m.frame.width<=rotated.width && m.frame.height<=rotated.height);
    assert(MWWindowToggleMaximize(&m,rotated));
    equal_rect(m.frame,MWFitAspectRect(original,rotated,m.aspectRatio));
}

static void proportional_scaling(void) {
    MWRect viewport={8,60,414,780}, initial={30,90,240,48+240.0*932/430};
    double ratio=430.0/932;
    for(int dx=-800;dx<800;dx+=19) for(int dy=-800;dy<800;dy+=23) {
        MWRect r=MWResizeAspectRect(initial,dx,dy,viewport,ratio);
        assert(fabs(r.width/(r.height-MWTitleHeight)-ratio)<0.00001);
        assert(r.x>=viewport.x && r.y>=viewport.y);
        assert(r.x+r.width<=viewport.x+viewport.width+0.001);
        assert(r.y+r.height<=viewport.y+viewport.height+0.001);
    }
    MWRect wide=MWMaximizedAspectRect((MWRect){60,8,800,340},932.0/430);
    assert(fabs(wide.width/(wide.height-MWTitleHeight)-932.0/430)<0.00001);
    MWRect tiny=MWFitAspectRect(initial,(MWRect){0,0,100,120},ratio);
    assert(fabs(tiny.width/(tiny.height-MWTitleHeight)-ratio)<0.00001);
    assert(tiny.width<=100 && tiny.height<=120);
    assert(isfinite(MWFitAspectRect(initial,viewport,NAN).width));
    equal_rect(MWResizeAspectRect(initial,100,100,(MWRect){0,0,20,30},ratio),(MWRect){0,0,20,30});
    for(int height=47;height<56;height++) {
        const double ratios[]={0.02,0.1,0.25,0.5,2,8};
        for(unsigned i=0;i<sizeof(ratios)/sizeof(ratios[0]);i++) {
            MWRect r=MWResizeAspectRect(initial,300,300,(MWRect){0,0,100,height},ratios[i]);
            assert(r.width<=100 && r.height<=height+0.00001);
        }
    }
    MWRect handle=MWEdgeHandleRect((MWRect){0,59,430,839},true,2.0);
    equal_rect(handle,(MWRect){386,850,44,48});
    handle=MWEdgeHandleRect((MWRect){44,0,844,396},false,NAN);
    assert(handle.x==44 && isfinite(handle.y) && handle.width==44);
}

int main(void) {
    lifecycle(); bounds(); maximize_restore(); proportional_scaling();
    puts("PASS: lifecycle, boundaries, proportional scaling, maximize/restore, rotation and edge handle");
    return 0;
}
