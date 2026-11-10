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
    for(int height=(int)MWWindowChromeHeight-1;height<MWWindowChromeHeight+8;height++) {
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
    assert(MWWindowChromeHeight<=36 && MWResizeRailHeight<=8);
    for(int height=200;height<=950;height+=23) for(int width=220;width<=900;width+=61) {
        MWRect bounds={0,0,width,height};
        MWRect content=MWWindowContentRect(bounds,0,false);
        MWRect rail=MWWindowRailRect(bounds,false);
        assert(content.y==MWTitleHeight);
        assert(content.y+content.height<=rail.y+0.001);
        assert(rail.height==MWResizeRailHeight && rail.y+rail.height==height);
        assert(rail.width==width); // The entire thin strip starts proportional resize.
        assert(MWCornerTouchSize<=MWTitleHeight);
        assert(content.height>=height-36);
        equal_rect(MWWindowContentRect(bounds,0,true),bounds);
        assert(MWWindowRailRect(bounds,true).height==0);
    }
    MWRect content=MWWindowContentRect((MWRect){0,0,320,466},59,false);
    assert(content.y==MWTitleHeight+59);
    assert(content.y+content.height==466-MWResizeRailHeight);
    MWRect tiny=MWWindowContentRect((MWRect){0,0,20,30},59,false);
    assert(tiny.height>=0 && tiny.y+tiny.height<=30);
}
static void guest_safe_insets(void) {
    MWRect safe={0,59,430,839}; // Device-style safe rect, no production hardcoding.
    MWInsets i=MWGuestSafeInsets((MWRect){0,0,430,932},safe,430,932);
    assert(i.top==59 && i.bottom==34 && i.left==0 && i.right==0);
    // 28pt header/8pt rail: guest extends26pt into the Home zone.
    i=MWGuestSafeInsets((MWRect){0,28,430,896},safe,430,896);
    assert(i.top==31 && i.bottom==26);
    // Proportional scene gets the inset in guest points, not screen points.
    double scale=896.0/932;
    i=MWGuestSafeInsets((MWRect){0,28,430*scale,896},safe,430,932);
    assert(fabs(i.bottom-26/scale)<0.00001);
    i=MWGuestSafeInsets((MWRect){20,100,300,500},safe,430,932);
    assert(i.top==0 && i.bottom==0 && i.left==0 && i.right==0);
    i=MWGuestSafeInsets((MWRect){0,0,932,430},(MWRect){59,0,814,409},932,430);
    assert(i.left==59 && i.right==59 && i.bottom==21 && i.top==0);
    i=MWGuestSafeInsets((MWRect){0,920,430,8},safe,430,100);
    assert(i.bottom==100 && i.top==0); // Fully within excluded strip, bounded.
    i=MWGuestSafeInsets((MWRect){0,0,0,0},safe,430,932);
    assert(i.top==0 && i.bottom==0);
    i=MWGuestSafeInsets((MWRect){NAN,0,430,932},safe,430,932);
    assert(i.top==0 && i.bottom==0);
}
static void compatible_guest_canvas(void) {
    MWRect native={0,0,390,844},tiny={0,0,390,164};
    // Device evidence: a saved200pt window launched only164pt of App content.
    equal_rect(MWGuestCanvas(tiny,native,false,false,false),tiny);
    equal_rect(MWGuestCanvas(tiny,native,false,false,true),native);
    equal_rect(MWGuestCanvas(tiny,native,true,false,false),native);
    equal_rect(MWGuestCanvas(tiny,native,true,true,false),tiny);
    equal_rect(MWGuestCanvas(tiny,native,false,true,true),native);
    MWRect landscape={0,0,844,390};
    equal_rect(MWGuestCanvas(tiny,landscape,false,false,true),landscape);
    for(int w=220;w<=390;w+=17) for(int h=164;h<=844;h+=29) {
        MWRect fixed=MWGuestCanvas((MWRect){0,0,w,h},native,false,false,true);
        equal_rect(fixed,native);
        MWContentTransform t=MWFitContent(fixed.width,fixed.height,w,h);
        assert(t.scale>0 && t.x>=-0.00001 && t.y>=-0.00001);
        assert(t.x+fixed.width*t.scale<=w+0.00001 && t.y+fixed.height*t.scale<=h+0.00001);
    }
}
static void deliberate_resize_and_layout_restore(void) {
    assert(!MWResizeDragActivated(0,0) && !MWResizeDragActivated(5,5) && !MWResizeDragActivated(13,0));
    assert(MWResizeDragActivated(14,0) && MWResizeDragActivated(0,-14));
    assert(!MWResizeDragActivated(NAN,10));
    MWRect viewport={0,0,430,932},half={0,0,430,466};
    MWRect r=MWBeginProportionalResize(half,viewport,430.0/932,59);
    assert(r.y>=59 && fabs(r.width/(r.height-MWWindowChromeHeight)-430.0/932)<0.00001);
    assert(fabs(r.x-(430-r.width)/2)<0.001); // Do not pin the smaller result to the left.
    assert(r.width<=half.width && r.height<=half.height);
    assert(r.y+r.height<=half.y+half.height+0.001); // No full-height expansion from halfscreen.
    MWWindowModel m=MWWindowCreate((MWRect){20,10,300,500}); MWWindowApply(&m,MWEventReady);
    MWWindowModel next=MWWindowRestoreForLaunch(m,viewport);
    equal_rect(next.frame,m.frame); assert(next.state==MWWindowLoading && next.resizeMode==m.resizeMode);
    MWWindowSnap(&m,MWSnapBottom,viewport);
    next=MWWindowRestoreForLaunch(m,viewport);
    assert(next.snapTarget==MWSnapBottom); equal_rect(next.frame,m.frame);
    MWWindowToggleMaximize(&m,viewport); next=MWWindowRestoreForLaunch(m,viewport);
    assert(next.maximized && next.restoreSnapTarget==MWSnapBottom); equal_rect(next.restoreFrame,m.restoreFrame);
}
static bool intersects(MWRect a,MWRect b) {
    return a.x<b.x+b.width && b.x<a.x+a.width && a.y<b.y+b.height && b.y<a.y+a.height;
}
static void four_corner_controls_and_resize(void) {
    MWRect screen={0,0,390,844},usable=MWProportionalViewport(screen,47);
    MWRect half={0,47,390,375}; // Top half after removing extra title inset.
    MWRect fit=MWBeginProportionalResize(half,screen,390.0/844,47);
    assert(fit.width<220 && fit.height<=375 && fit.y>=47);
    equal_rect(MWResizeAspectCornerRect(fit,0,0,usable,390.0/844,false),fit);
    equal_rect(MWResizeAspectCornerRect(fit,0,0,usable,390.0/844,true),fit);
    MWRect br=MWResizeAspectCornerRect(fit,-10,-20,usable,390.0/844,false);
    MWRect tl=MWResizeAspectCornerRect(fit,10,20,usable,390.0/844,true);
    assert(br.width<fit.width && tl.width<fit.width);
    assert(br.x==fit.x && br.y==fit.y);
    assert(fabs(tl.x+tl.width-fit.x-fit.width)<0.001 && fabs(tl.y+tl.height-fit.y-fit.height)<0.001);
    MWRect left=MWResizeFreeCornerRect(fit,12,-12,screen,true);
    assert(left.width<fit.width && left.height<fit.height && left.y==fit.y);
    assert(fabs(left.x+left.width-fit.x-fit.width)<0.001);
    MWRect right=MWResizeFreeCornerRect(fit,-12,12,screen,false);
    assert(right.width<fit.width && right.height<fit.height && right.x==fit.x);
    assert(fabs(right.y+right.height-fit.y-fit.height)<0.001);
    for(int dx=-800;dx<800;dx+=37) for(int dy=-800;dy<800;dy+=41) for(int top=0;top<2;top++) {
        MWRect resized=MWResizeAspectCornerRect(fit,dx,dy,usable,390.0/844,top);
        assert(resized.x>=usable.x-0.001 && resized.y>=usable.y-0.001);
        assert(resized.x+resized.width<=usable.x+usable.width+0.001 && resized.y+resized.height<=844.001);
        assert(fabs(resized.width/(resized.height-MWWindowChromeHeight)-390.0/844)<0.00001);
    }
    for(int width=80;width<=900;width+=13) {
        MWRect bounds={0,0,width,300};
        MWWindowControls c=MWWindowControlRects(bounds,47,0,0);
        MWRect parts[]={c.topLeft,c.topRight,c.bottomLeft,c.bottomRight,c.buttons[0],c.buttons[1],c.buttons[2],c.buttons[3]};
        MWRect content=MWWindowContentRect(bounds,47,false);
        for(unsigned i=0;i<8;i++) {
            assert(parts[i].x>=0 && parts[i].y>=0 && parts[i].x+parts[i].width<=width+0.001 && parts[i].y+parts[i].height<=300);
            assert(!intersects(parts[i],content));
            for(unsigned j=i+1;j<8;j++) assert(!intersects(parts[i],parts[j]));
        }
        assert(c.bottomLeft.width+c.bottomRight.width==width);
        assert(fabs((c.buttons[0].x+c.buttons[3].x+c.buttons[3].width)/2-width/2.0)<0.001);
    }
    MWWindowModel m=MWWindowCreate(fit); m.resizeMode=MWResizeProportional; m.aspectRatio=390.0/844;
    MWWindowReflow(&m,screen); equal_rect(m.frame,fit); // Restore/reflow must not re-expand below220pt.
    m.resizeMode=MWResizeFree; m.frame=(MWRect){20,70,135,150}; MWRect small=m.frame;
    MWWindowReflow(&m,screen); equal_rect(m.frame,small);
    equal_rect(MWConstrainExistingRect(small,screen),small); // Saved free windows also remain small.
    equal_rect(MWConstrainExistingRect((MWRect){10,30,112,235},screen),(MWRect){10,30,112,235});
    equal_rect(MWResizeFreeCornerRect((MWRect){10,30,112,235},0,0,screen,true),(MWRect){10,30,112,235});
    // Reviewed regression: rotation makes a compact aspect window only54pt high.
    MWRect shortWindow={20,0,38.815,53.936};
    MWRect reachable=MWKeepShortTitleReachable(shortWindow,screen,47);
    assert(reachable.y>=47 && reachable.width==shortWindow.width && reachable.height==shortWindow.height);
    MWWindowControls shortControls=MWWindowControlRects((MWRect){0,0,reachable.width,reachable.height},0,0,0);
    assert(reachable.y+shortControls.topLeft.y>=47);
    for(unsigned i=0;i<4;i++) {
        assert(shortControls.buttons[i].y==shortControls.topLeft.y);
        assert(shortControls.buttons[i].y+shortControls.buttons[i].height<=reachable.height-MWResizeRailHeight);
    }
    for(int height=37;height<=170;height+=7) {
        MWRect frame=MWKeepShortTitleReachable((MWRect){0,0,120,height},screen,59);
        double inset=fmax(0,59-frame.y);
        MWWindowControls c=MWWindowControlRects((MWRect){0,0,120,height},inset,0,0);
        assert(frame.y+c.topLeft.y>=59);
        for(unsigned i=0;i<4;i++) assert(c.buttons[i].y==c.topLeft.y && c.buttons[i].height==c.topLeft.height);
    }
}
static void parked_roundtrip_and_placement(void) {
    MWRect viewport={0,0,430,932}; MWWindowModel m=MWWindowCreate((MWRect){20,100,300,500});
    MWWindowParking p={0}; assert(!MWWindowPark(&m,&p));
    MWWindowApply(&m,MWEventReady); MWWindowModel saved=m;
    assert(MWWindowPark(&m,&p) && m.state==MWWindowParked);
    assert(!MWWindowPark(&m,&p));
    assert(MWWindowUnpark(&m,&p,viewport)); equal_rect(m.frame,saved.frame);
    assert(m.resizeMode==saved.resizeMode && m.aspectRatio==saved.aspectRatio);
    MWWindowSnap(&m,MWSnapTop,viewport); saved=m;
    assert(MWWindowPark(&m,&p) && MWWindowUnpark(&m,&p,viewport));
    assert(m.snapTarget==saved.snapTarget); equal_rect(m.frame,saved.frame);
    MWWindowToggleMaximize(&m,viewport); saved=m;
    assert(MWWindowPark(&m,&p) && MWWindowUnpark(&m,&p,viewport));
    assert(m.maximized && m.restoreSnapTarget==saved.restoreSnapTarget); equal_rect(m.restoreFrame,saved.restoreFrame);
    assert(MWWindowPark(&m,&p)); MWWindowApply(&m,MWEventClose);
    assert(!MWWindowUnpark(&m,&p,viewport)); // A thumbnail cannot revive a closed session.
    m=MWWindowCreate((MWRect){20,70,260,600}); p=(MWWindowParking){0};
    MWWindowApply(&m,MWEventReady); m.resizeMode=MWResizeProportional; m.aspectRatio=430.0/932;
    MWWindowReflow(&m,viewport); saved=m; assert(MWWindowPark(&m,&p));
    MWRect thumbnail=MWParkedRect((MWRect){0,59,430,839},m.aspectRatio,0.5,16.0/9,0,1);
    assert(fabs(thumbnail.width/thumbnail.height-16.0/9)<0.00001);
    assert(MWWindowUnpark(&m,&p,viewport)); equal_rect(m.frame,saved.frame);
    assert(m.resizeMode==MWResizeProportional && m.aspectRatio==saved.aspectRatio);
    assert(MWWindowPark(&m,&p));
    assert(MWWindowUnpark(&m,&p,(MWRect){0,0,932,430}));
    assert(m.frame.x>=0 && m.frame.y>=0 && m.frame.x+m.frame.width<=932.001 && m.frame.y+m.frame.height<=430.001);
    const MWRect areas[]={{0,59,430,839},{44,0,844,409},{0,20,320,548},{0,0,28,40}};
    const double aspects[]={0,1,4.0/3,3.0/4,16.0/9,9.0/16};
    for(unsigned a=0;a<4;a++) for(unsigned count=1;count<=4;count++)
        for(unsigned ratio=0;ratio<6;ratio++) for(unsigned slot=0;slot<count;slot++) {
            MWRect r=MWParkedRect(areas[a],430.0/932,0.36,aspects[ratio],slot,count);
            assert(r.width>0 && r.height>0 && r.x>=areas[a].x && r.y>=areas[a].y);
            assert(r.x+r.width<=areas[a].x+areas[a].width+0.001 && r.y+r.height<=areas[a].y+areas[a].height+0.001);
            double expected=aspects[ratio]>0 ? aspects[ratio] : 430.0/932;
            assert(fabs(r.width/r.height-expected)<0.00001);
            if(slot>0) {
                MWRect previous=MWParkedRect(areas[a],430.0/932,0.36,aspects[ratio],slot-1,count);
                assert(r.y>=previous.y+previous.height);
            }
        }
}

int main(void) {
    lifecycle(); bounds(); maximize_restore(); proportional_scaling(); free_resize_and_snap(); original_canvas_and_reachable_snap(); free_entry_placement(); isolated_resize_rail(); guest_safe_insets(); compatible_guest_canvas(); deliberate_resize_and_layout_restore(); parked_roundtrip_and_placement(); four_corner_controls_and_resize();
    puts("PASS: lifecycle, free/proportional resize, full/half-screen, top inset continuity, rotation and edge handle");
    return 0;
}
