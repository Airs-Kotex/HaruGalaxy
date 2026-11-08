// SPDX-License-Identifier: Apache-2.0
#include "MWWindowModel.h"
#include <math.h>

static double finite_or(double n, double fallback) { return isfinite(n) ? n : fallback; }
static double clamp(double n, double low, double high) { return fmin(fmax(n,low),high); }
static MWRect safe_viewport(MWRect v) {
    v.x=finite_or(v.x,0); v.y=finite_or(v.y,0);
    v.width=fmax(1,finite_or(v.width,1)); v.height=fmax(1,finite_or(v.height,1));
    return v;
}

MWRect MWConstrainRect(MWRect r, MWRect viewport) {
    MWRect v=safe_viewport(viewport);
    r.width=clamp(finite_or(r.width,240),fmin(220,v.width),v.width);
    r.height=clamp(finite_or(r.height,360),fmin(200,v.height),v.height);
    r.x=clamp(finite_or(r.x,v.x),v.x,v.x+v.width-r.width);
    r.y=clamp(finite_or(r.y,v.y),v.y,v.y+v.height-r.height);
    return r;
}

MWWindowModel MWWindowCreate(MWRect frame) {
    MWWindowModel m={MWWindowLoading,frame,frame,false,frame.width/fmax(1,frame.height-MWTitleHeight)};
    return m;
}

bool MWWindowApply(MWWindowModel *m, MWWindowEvent e) {
    if (!m || m->state==MWWindowClosed) return false;
    switch(e) {
        case MWEventReady:
            if(m->state!=MWWindowLoading) return false;
            m->state=MWWindowVisible; break;
        case MWEventFailed:
            if(m->state==MWWindowFailed) return false;
            m->state=MWWindowFailed; break;
        case MWEventRetry:
            if(m->state!=MWWindowFailed) return false;
            m->state=MWWindowLoading; break;
        case MWEventMinimize:
            if(m->state!=MWWindowVisible) return false;
            m->state=MWWindowMinimized; break;
        case MWEventRestore:
            if(m->state!=MWWindowMinimized) return false;
            m->state=MWWindowVisible; break;
        case MWEventClose: m->state=MWWindowClosed; break;
        default: return false;
    }
    return true;
}

bool MWWindowToggleMaximize(MWWindowModel *m, MWRect viewport) {
    if(!m || m->state!=MWWindowVisible) return false;
    if(m->maximized) m->frame=MWFitAspectRect(m->restoreFrame,viewport,m->aspectRatio);
    else { m->restoreFrame=m->frame; m->frame=MWMaximizedAspectRect(viewport,m->aspectRatio); }
    m->maximized=!m->maximized;
    return true;
}

void MWWindowReflow(MWWindowModel *m, MWRect viewport) {
    if(!m) return;
    m->frame=m->maximized ? MWMaximizedAspectRect(viewport,m->aspectRatio) : MWFitAspectRect(m->frame,viewport,m->aspectRatio);
}

static double safe_ratio(double r) { return isfinite(r) && r>0.01 && r<100 ? r : 0.5; }
MWRect MWFitAspectRect(MWRect r, MWRect viewport, double ratio) {
    MWRect v=safe_viewport(viewport); ratio=safe_ratio(ratio);
    if(v.height<=MWTitleHeight+1) return v; // No positive content height can fit.
    double maximum=fmin(v.width,(v.height-MWTitleHeight)*ratio);
    double minimum=fmin(maximum,fmax(220,(200-MWTitleHeight)*ratio));
    r.width=clamp(finite_or(r.width,minimum),minimum,maximum);
    r.height=r.width/ratio+MWTitleHeight;
    r.x=clamp(finite_or(r.x,v.x),v.x,v.x+v.width-r.width);
    r.y=clamp(finite_or(r.y,v.y),v.y,v.y+v.height-r.height);
    return r;
}
MWRect MWResizeAspectRect(MWRect start, double dx, double dy, MWRect viewport, double ratio) {
    MWRect v=safe_viewport(viewport); ratio=safe_ratio(ratio);
    if(v.height<=MWTitleHeight+1) return v;
    start=MWFitAspectRect(start,v,ratio);
    double content=fmax(1,start.height-MWTitleHeight);
    double scale=1+(finite_or(dx,0)*start.width+finite_or(dy,0)*content)/(start.width*start.width+content*content);
    double maximum=fmin(v.x+v.width-start.x,(v.y+v.height-start.y-MWTitleHeight)*ratio);
    double minimum=fmin(maximum,fmax(220,(200-MWTitleHeight)*ratio));
    start.width=clamp(start.width*scale,minimum,maximum);
    start.height=start.width/ratio+MWTitleHeight;
    return start;
}
MWRect MWMaximizedAspectRect(MWRect viewport, double ratio) {
    MWRect v=safe_viewport(viewport);
    MWRect r=MWFitAspectRect((MWRect){v.x,v.y,v.width,v.height},v,ratio);
    r.x=v.x+(v.width-r.width)/2; r.y=v.y+(v.height-r.height)/2;
    return r;
}
MWRect MWEdgeHandleRect(MWRect viewport, bool right, double position) {
    MWRect v=safe_viewport(viewport);
    double height=fmin(48,v.height),width=fmin(44,v.width);
    double normalized=clamp(finite_or(position,0.35),0,1);
    return (MWRect){right ? v.x+v.width-width : v.x,v.y+normalized*(v.height-height),width,height};
}
