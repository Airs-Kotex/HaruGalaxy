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
    MWWindowModel m={.state=MWWindowLoading,.frame=frame,.restoreFrame=frame,.maximized=false,
        .aspectRatio=frame.width/fmax(1,frame.height-MWTitleHeight),.resizeMode=MWResizeFree,.restoreResizeMode=MWResizeFree,
        .snapTarget=MWSnapNone,.restoreSnapTarget=MWSnapNone};
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
    if(m->maximized) {
        m->resizeMode=m->restoreResizeMode; m->snapTarget=MWReorientedSnapTarget(viewport,m->restoreSnapTarget);
        m->frame=m->snapTarget!=MWSnapNone ? MWHalfScreenRect(viewport,m->snapTarget) :
            (m->resizeMode==MWResizeProportional ? MWFitAspectRect(m->restoreFrame,viewport,m->aspectRatio) : MWConstrainRect(m->restoreFrame,viewport));
    } else {
        m->restoreFrame=m->frame; m->restoreResizeMode=m->resizeMode; m->restoreSnapTarget=m->snapTarget;
        m->snapTarget=MWSnapNone; m->frame=safe_viewport(viewport);
    }
    m->maximized=!m->maximized;
    return true;
}

void MWWindowReflow(MWWindowModel *m, MWRect viewport) {
    if(!m) return;
    if(m->maximized) { m->frame=safe_viewport(viewport); m->restoreSnapTarget=MWReorientedSnapTarget(viewport,m->restoreSnapTarget); }
    else if(m->snapTarget!=MWSnapNone) {
        m->snapTarget=MWReorientedSnapTarget(viewport,m->snapTarget);
        m->frame=MWHalfScreenRect(viewport,m->snapTarget);
    }
    else m->frame=m->resizeMode==MWResizeProportional ? MWFitAspectRect(m->frame,viewport,m->aspectRatio) : MWConstrainRect(m->frame,viewport);
}

MWRect MWResizeFreeRect(MWRect start,double dx,double dy,MWRect viewport,bool leftHandle) {
    MWRect v=safe_viewport(viewport); start=MWConstrainRect(start,v);
    double right=start.x+start.width;
    double maxWidth=leftHandle ? right-v.x : v.x+v.width-start.x;
    double maxHeight=v.y+v.height-start.y;
    start.width=clamp(start.width+(leftHandle ? -1 : 1)*finite_or(dx,0),fmin(220,maxWidth),maxWidth);
    start.height=clamp(start.height+finite_or(dy,0),fmin(200,maxHeight),maxHeight);
    if(leftHandle) start.x=right-start.width;
    return start;
}
MWRect MWResizeTopRightRect(MWRect start,double dx,double dy,MWRect viewport) {
    MWRect v=safe_viewport(viewport); start=MWConstrainRect(start,v);
    double bottom=start.y+start.height,maxWidth=v.x+v.width-start.x,maxHeight=bottom-v.y;
    start.width=clamp(start.width+finite_or(dx,0),fmin(220,maxWidth),maxWidth);
    start.height=clamp(start.height-finite_or(dy,0),fmin(200,maxHeight),maxHeight);
    start.y=bottom-start.height; return start;
}
MWRect MWMoveRect(MWRect start,double dx,double dy,MWRect viewport) {
    MWRect v=safe_viewport(viewport);
    start.x=clamp(start.x+finite_or(dx,0),v.x,v.x+fmax(0,v.width-start.width));
    start.y=clamp(start.y+finite_or(dy,0),v.y,v.y+fmax(0,v.height-start.height));
    return start;
}
MWRect MWSystemCanvas(double width,double height,bool landscape) {
    double w=fmax(1,finite_or(width,430)),h=fmax(1,finite_or(height,932));
    return (MWRect){0,0,landscape ? fmax(w,h) : fmin(w,h),landscape ? fmin(w,h) : fmax(w,h)};
}
bool MWCornerHit(double x,double y,double width,double height,bool top) {
    if(!isfinite(x)||!isfinite(y)||x<0||y<0||x>width||y>height) return false;
    return x>=width-12 || (top ? y<=12 : y>=height-12);
}
MWRect MWUnpinFrame(MWRect frame,double extraTopInset) {
    double inset=clamp(finite_or(extraTopInset,0),0,fmax(0,frame.height-MWTitleHeight-1));
    frame.y+=inset; frame.height-=inset;
    return frame;
}
MWRect MWHalfScreenRect(MWRect viewport,MWSnapTarget target) {
    MWRect r=safe_viewport(viewport);
    switch(target) {
        case MWSnapTop: r.height/=2; break;
        case MWSnapBottom: r.height/=2; r.y+=r.height; break;
        case MWSnapLeft: r.width/=2; break;
        case MWSnapRight: r.width/=2; r.x+=r.width; break;
        case MWSnapNone: break;
    }
    return r;
}
MWSnapTarget MWReorientedSnapTarget(MWRect viewport,MWSnapTarget target) {
    MWRect v=safe_viewport(viewport);
    if(v.height>=v.width) {
        if(target==MWSnapLeft) return MWSnapTop;
        if(target==MWSnapRight) return MWSnapBottom;
    } else {
        if(target==MWSnapTop) return MWSnapLeft;
        if(target==MWSnapBottom) return MWSnapRight;
    }
    return target;
}
MWSnapTarget MWSnapTargetAtPoint(MWRect viewport,double x,double y) {
    if(!isfinite(x) || !isfinite(y)) return MWSnapNone;
    MWRect v=safe_viewport(viewport);
    if(x<v.x-24 || y<v.y-24 || x>v.x+v.width+24 || y>v.y+v.height+24) return MWSnapNone;
    if(v.height>=v.width) {
        double threshold=fmin(36,v.height/4);
        if(y<=v.y+threshold) return MWSnapTop;
        if(y>=v.y+v.height-threshold) return MWSnapBottom;
    } else {
        double threshold=fmin(36,v.width/4);
        if(x<=v.x+threshold) return MWSnapLeft;
        if(x>=v.x+v.width-threshold) return MWSnapRight;
    }
    return MWSnapNone;
}
MWSnapTarget MWSnapTargetForDrag(MWRect viewport,MWRect start,MWRect proposed) {
    MWRect v=safe_viewport(viewport);
    if(!isfinite(proposed.x)||!isfinite(proposed.y)||!isfinite(proposed.width)||!isfinite(proposed.height)) return MWSnapNone;
    double dx=proposed.x-start.x,dy=proposed.y-start.y;
    if(v.height>=v.width) {
        if(dy<=-24 && proposed.y<=v.y+48) return MWSnapTop;
        if(dy>=24 && proposed.y+proposed.height>=v.y+v.height-48) return MWSnapBottom;
    } else {
        if(dx<=-24 && proposed.x<=v.x+48) return MWSnapLeft;
        if(dx>=24 && proposed.x+proposed.width>=v.x+v.width-48) return MWSnapRight;
    }
    return MWSnapNone;
}
bool MWWindowSnap(MWWindowModel *m,MWSnapTarget target,MWRect viewport) {
    if(!m || m->state!=MWWindowVisible || m->resizeMode!=MWResizeFree || target==MWSnapNone) return false;
    m->maximized=false; m->snapTarget=MWReorientedSnapTarget(viewport,target); m->frame=MWHalfScreenRect(viewport,m->snapTarget); return true;
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
    double height=fmin(MWEdgeTouchHeight,v.height),width=fmin(MWEdgeTouchWidth,v.width);
    double normalized=clamp(finite_or(position,0.35),0,1);
    return (MWRect){right ? v.x+v.width-width : v.x,v.y+normalized*(v.height-height),width,height};
}
MWContentTransform MWFitContent(double logicalWidth,double logicalHeight,double availableWidth,double availableHeight) {
    double lw=fmax(1,finite_or(logicalWidth,1)),lh=fmax(1,finite_or(logicalHeight,1));
    double aw=fmax(0,finite_or(availableWidth,0)),ah=fmax(0,finite_or(availableHeight,0));
    double scale=fmin(aw/lw,ah/lh);
    return (MWContentTransform){scale,(aw-lw*scale)/2,(ah-lh*scale)/2};
}
