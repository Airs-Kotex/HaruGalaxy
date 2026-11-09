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
    assert(fabs(m.frame.width/(m.frame.height-MWWindowChromeHeight)-0.5)<0.00001);
    MWRect pinned={0,0,430,466};
    MWRect detached=MWUnpinFrame(pinned,59);
    equal_rect(detached,(MWRect){0,59,430,407});
    // Both modes start with the same screen-space guest origin and dimensions.
    assert(detached.y+MWTitleHeight==pinned.y+59+MWTitleHeight);
    assert(detached.height-MWWindowChromeHeight==pinned.height-59-MWWindowChromeHeight);
    equal_rect(MWResizeFreeRect(detached,0,0,screen,true),detached);
    equal_rect(MWResizeAspectRect(detached,0,0,screen,430.0/(407-MWWindowChromeHeight)),detached);
    for(int dx=-600;dx<600;dx+=23) for(int dy=-500;dy<900;dy+=29) {
        r=MWResizeFreeRect(start,dx,dy,screen,true);
        assert(r.x>=0 && r.y>=0 && r.x+r.width<=430.001 && r.y+r.height<=932.001);
        assert(fabs(r.x+r.width-340)<0.0001);
    }
}

static void original_canvas_and_reachable_snap(void) {
    MWRect screen={0,0,430,932},start={20,100,320,460};
    MWRect canvas=MWSystemCanvas(430,932,false);
    equal_rect(canvas,(MWRect){0,0,430,932});
    equal_rect(MWSystemCanvas(430,932,true),(MWRect){0,0,932,430});
    MWRect changed=MWResizeTopRightRect(start,40,-30,screen);
    equal_rect(changed,(MWRect){20,70,360,490});
    assert(changed.y+changed.height==start.y+start.height);
    assert(MWSnapTargetForDrag(screen,start,(MWRect){20,400,320,460})==MWSnapNone);
    assert(MWSnapTargetForDrag(screen,start,(MWRect){20,430,320,460})==MWSnapBottom);
    assert(MWSnapTargetForDrag(screen,start,(MWRect){20,30,320,460})==MWSnapTop);
    assert(MWSnapTargetForDrag(screen,(MWRect){20,472,320,460},(MWRect){20,480,320,460})==MWSnapNone);
    assert(MWSnapTargetForDrag((MWRect){0,0,932,430},(MWRect){100,10,400,300},(MWRect){500,10,400,300})==MWSnapRight);
    MWRect top=MWMoveRect(start,0,-100,screen);
    assert(top.y==0 && top.width==start.width && top.height==start.height);
    assert(MWCornerHit(23,4,28,28,true));
    assert(MWCornerHit(25,23,28,28,true));
    assert(!MWCornerHit(4,23,28,28,true));
    assert(MWCornerHit(5,25,28,28,false));
    assert(!MWCornerHit(5,4,28,28,false));
    assert(!MWCornerHit(-1,10,28,28,false));
    assert(MWCornerHit(20,20,44,44,false)); // Interior of the larger corner target.
    assert(MWCornerHit(21,23,44,44,true));
    assert(!MWCornerHit(0,0,44,44,false)); // Keep the far interior corner pass-through.
}

static void proportional_scaling(void) {
    MWRect viewport={8,60,414,780}, initial={30,90,240,MWWindowChromeHeight+240.0*932/430};
    double ratio=430.0/932;
    for(int dx=-800;dx<800;dx+=19) for(int dy=-800;dy<800;dy+=23) {
        MWRect r=MWResizeAspectRect(initial,dx,dy,viewport,ratio);
        assert(fabs(r.width/(r.height-MWWindowChromeHeight)-ratio)<0.00001);
        assert(r.x>=viewport.x && r.y>=viewport.y);
        assert(r.x+r.width<=viewport.x+viewport.width+0.001);
        assert(r.y+r.height<=viewport.y+viewport.height+0.001);
    }
    MWRect wide=MWMaximizedAspectRect((MWRect){60,8,800,340},932.0/430);
    assert(fabs(wide.width/(wide.height-MWWindowChromeHeight)-932.0/430)<0.00001);
    MWRect tiny=MWFitAspectRect(initial,(MWRect){0,0,100,120},ratio);
    assert(fabs(tiny.width/(tiny.height-MWWindowChromeHeight)-ratio)<0.00001);
    assert(tiny.width<=100 && tiny.height<=120);
    assert(isfinite(MWFitAspectRect(initial,viewport,NAN).width));
    equal_rect(MWResizeAspectRect(initial,100,100,(MWRect){0,0,20,30},ratio),(MWRect){0,0,20,30});
    for(int height=91;height<100;height++) {
        const double ratios[]={0.02,0.1,0.25,0.5,2,8};
        for(unsigned i=0;i<sizeof(ratios)/sizeof(ratios[0]);i++) {
            MWRect r=MWResizeAspectRect(initial,300,300,(MWRect){0,0,100,height},ratios[i]);
            assert(r.width<=100 && r.height<=height+0.00001);
        }
    }
    MWRect handle=MWEdgeHandleRect((MWRect){0,59,430,839},true,2.0);
    equal_rect(handle,(MWRect){374,822,56,76});
    handle=MWEdgeHandleRect((MWRect){44,0,844,396},false,NAN);
    assert(handle.x==44 && isfinite(handle.y) && handle.width==56);
    equal_rect(MWEdgeHandleRect((MWRect){0,0,32,50},true,0.5),(MWRect){0,0,32,50});
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

static void free_entry_placement(void) {
    MWRect v={0,59,430,839};
    MWEntryPlacement p=MWEntryDrop(v,170,320);
    equal_rect(p.frame,(MWRect){170,320,56,76});
    assert(!p.docked);
    equal_rect(MWEntryRect(v,p.xPosition,p.yPosition),p.frame);
    p=MWEntryDrop(v,10,320); assert(p.docked && !p.right && p.frame.x==0);
    p=MWEntryDrop(v,365,320); assert(p.docked && p.right && p.frame.x==374);
    p=MWEntryDrop(v,20,320); assert(!p.docked && p.frame.x==20);
    p=MWEntryDrop(v,-200,2000); assert(p.docked && p.frame.x==0 && p.frame.y==822);
    p=MWEntryDrop((MWRect){0,0,32,50},20,100); equal_rect(p.frame,(MWRect){0,0,32,50});
    p=MWEntryDrop(v,NAN,INFINITY);
    assert(isfinite(p.xPosition) && isfinite(p.yPosition));
    for(int x=-100;x<600;x+=7) for(int y=-100;y<1100;y+=19) {
        p=MWEntryDrop(v,x,y);
        assert(p.frame.x>=v.x && p.frame.y>=v.y && p.frame.x+p.frame.width<=430.001 && p.frame.y+p.frame.height<=898.001);
        equal_rect(MWEntryRect(v,p.xPosition,p.yPosition),p.frame);
        MWRect rotated=MWEntryRect((MWRect){40,0,840,390},p.xPosition,p.yPosition);
        assert(rotated.x>=40 && rotated.x+rotated.width<=880.001 && rotated.y>=0 && rotated.y+rotated.height<=390.001);
    }
    MWRect panel=MWPanelPlacementRect(v,(MWRect){187,400,56,76},550);
    assert(panel.y>=484 || panel.y+panel.height<=392);
    assert(panel.x>=v.x && panel.x+panel.width<=v.x+v.width);
    assert(panel.y>=v.y && panel.y+panel.height<=v.y+v.height);
    panel=MWPanelPlacementRect(v,(MWRect){374,320,56,76},334);
    assert(panel.x+panel.width<=366);
    panel=MWPanelPlacementRect((MWRect){0,0,932,430},(MWRect){430,177,56,76},550);
    assert(panel.x+panel.width<=422 || panel.x>=494);
    panel=MWPanelPlacementRect((MWRect){0,0,667,375},(MWRect){305.5,149.5,56,76},550);
    assert(panel.height>=228 && panel.width>=220);
    assert(panel.x+panel.width<=297.5 || panel.x>=369.5);
    assert(panel.y>=8 && panel.y+panel.height<=367.001);
    panel=MWPanelPlacementRect((MWRect){0,20,320,548},(MWRect){132,256,56,76},550);
    assert(panel.height>=200 && panel.width>=220);
    assert(panel.y+panel.height<=248 || panel.y>=340);
}

static void isolated_resize_rail(void) {
    for(int height=200;height<=950;height+=23) for(int width=220;width<=900;width+=61) {
        MWRect bounds={0,0,width,height};
        MWRect content=MWWindowContentRect(bounds,0,false);
        MWRect rail=MWWindowRailRect(bounds,false);
        assert(content.y==MWTitleHeight);
        assert(content.y+content.height<=rail.y+0.001);
        assert(rail.height==MWResizeRailHeight && rail.y+rail.height==height);
        assert(MWCornerTouchSize<=rail.height);
        equal_rect(MWWindowContentRect(bounds,0,true),bounds);
        assert(MWWindowRailRect(bounds,true).height==0);
    }
    MWRect content=MWWindowContentRect((MWRect){0,0,320,466},59,false);
    assert(content.y==MWTitleHeight+59);
    assert(content.y+content.height==466-MWResizeRailHeight);
    MWRect tiny=MWWindowContentRect((MWRect){0,0,20,30},59,false);
    assert(tiny.height>=0 && tiny.y+tiny.height<=30);
}

int main(void) {
    lifecycle(); bounds(); maximize_restore(); proportional_scaling(); free_resize_and_snap(); original_canvas_and_reachable_snap(); free_entry_placement(); isolated_resize_rail();
    puts("PASS: lifecycle, free/proportional resize, full/half-screen, top inset continuity, rotation and edge handle");
    return 0;
}
