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

static void free_resize_and_snap(void) {
    MWRect screen={0,0,430,932}, start={40,80,300,500};
    MWRect r=MWResizeFreeRect(start,50,80,screen,true);
    equal_rect(r,(MWRect){90,80,250,580});
    assert(r.x+r.width==start.x+start.width);
    r=MWResizeFreeRect(start,-1000,2000,screen,true);
    assert(r.x==0 && r.width==340 && r.y+r.height==932);
    assert(MWSnapTargetAtPoint(screen,215,12)==MWSnapTop);
    assert(MWSnapTargetAtPoint(screen,215,920)==MWSnapBottom);
    assert(MWSnapTargetAtPoint(screen,3,400)==MWSnapNone);
    assert(MWSnapTargetAtPoint((MWRect){0,0,932,430},12,215)==MWSnapLeft);
    assert(MWSnapTargetAtPoint((MWRect){0,0,932,430},920,215)==MWSnapRight);
    assert(MWSnapTargetAtPoint(screen,NAN,12)==MWSnapNone);
    equal_rect(MWHalfScreenRect(screen,MWSnapTop),(MWRect){0,0,430,466});
    equal_rect(MWHalfScreenRect(screen,MWSnapBottom),(MWRect){0,466,430,466});
    equal_rect(MWHalfScreenRect((MWRect){0,0,933,430},MWSnapRight),(MWRect){466.5,0,466.5,430});
    MWWindowModel m=MWWindowCreate(start);
    assert(m.resizeMode==MWResizeFree);
    MWWindowApply(&m,MWEventReady);
    assert(MWWindowSnap(&m,MWSnapBottom,screen));
    equal_rect(m.frame,(MWRect){0,466,430,466});
    MWWindowReflow(&m,(MWRect){0,0,932,430});
    assert(m.snapTarget==MWSnapRight);
    equal_rect(m.frame,(MWRect){466,0,466,430});
    MWWindowReflow(&m,screen);
    assert(MWWindowToggleMaximize(&m,screen));
    equal_rect(m.frame,screen);
    assert(MWWindowToggleMaximize(&m,screen));
    assert(m.snapTarget==MWSnapBottom);
    equal_rect(m.frame,(MWRect){0,466,430,466});
    m.resizeMode=MWResizeProportional;
    assert(!MWWindowSnap(&m,MWSnapTop,screen));
    m.snapTarget=MWSnapNone;
    m.aspectRatio=0.5;
    MWWindowReflow(&m,screen);
    assert(fabs(m.frame.width/(m.frame.height-48)-0.5)<0.00001);
    MWRect pinned={0,0,430,466};
    MWRect detached=MWUnpinFrame(pinned,59);
    equal_rect(detached,(MWRect){0,59,430,407});
    // Both modes start with the same screen-space guest origin and dimensions.
    assert(detached.y+48==pinned.y+59+48);
    assert(detached.height-48==pinned.height-59-48);
    equal_rect(MWResizeFreeRect(detached,0,0,screen,true),detached);
    equal_rect(MWResizeAspectRect(detached,0,0,screen,430.0/359),detached);
    for(int dx=-600;dx<600;dx+=23) for(int dy=-500;dy<900;dy+=29) {
        r=MWResizeFreeRect(start,dx,dy,screen,true);
        assert(r.x>=0 && r.y>=0 && r.x+r.width<=430.001 && r.y+r.height<=932.001);
        assert(fabs(r.x+r.width-340)<0.0001);
    }
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
    const double logical[][2]={{430,932},{932,430}};
    const double container[][2]={{311.42703862660943,675},{240,360},{400,100},{0,0}};
    for(unsigned i=0;i<2;i++) for(unsigned j=0;j<4;j++) {
        MWContentTransform t=MWFitContent(logical[i][0],logical[i][1],container[j][0],container[j][1]);
        assert(isfinite(t.scale) && t.scale>=0 && t.x>=0 && t.y>=0);
        assert(t.x+logical[i][0]*t.scale<=container[j][0]+0.00001);
        assert(t.y+logical[i][1]*t.scale<=container[j][1]+0.00001);
        if(t.scale>0) {
            double pointX=123,pointY=234;
            assert(fabs(((pointX*t.scale+t.x)-t.x)/t.scale-pointX)<0.00001);
            assert(fabs(((pointY*t.scale+t.y)-t.y)/t.scale-pointY)<0.00001);
        }
    }
}

int main(void) {
    lifecycle(); bounds(); maximize_restore(); proportional_scaling(); free_resize_and_snap();
    puts("PASS: lifecycle, free/proportional resize, full/half-screen, top inset continuity, rotation and edge handle");
    return 0;
}
