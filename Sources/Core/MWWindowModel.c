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
MWInsets MWGuestSafeInsets(MWRect r,MWRect s,double w,double h) {
    if(!isfinite(r.x)||!isfinite(r.y)||!isfinite(r.width)||!isfinite(r.height)||
       !isfinite(s.x)||!isfinite(s.y)||!isfinite(s.width)||!isfinite(s.height)||
       !isfinite(w)||!isfinite(h)||r.width<=0||r.height<=0||s.width<0||s.height<0||w<=0||h<=0)
        return (MWInsets){0,0,0,0};
    double top=clamp(s.y-r.y,0,r.height),left=clamp(s.x-r.x,0,r.width);
    double bottom=clamp(r.y+r.height-s.y-s.height,0,r.height-top);
    double right=clamp(r.x+r.width-s.x-s.width,0,r.width-left);
    return (MWInsets){top*h/r.height,left*w/r.width,bottom*h/r.height,right*w/r.width};
}
MWRect MWGuestCanvas(MWRect available,MWRect systemCanvas,bool proportional,bool maximized,bool compatible) {
    MWRect result=safe_viewport(compatible || (proportional && !maximized) ? systemCanvas : available);
    result.x=0; result.y=0; return result;
}

MWRect MWConstrainRect(MWRect r, MWRect viewport) {
    MWRect v=safe_viewport(viewport);
    r.width=clamp(finite_or(r.width,240),fmin(220,v.width),v.width);
    r.height=clamp(finite_or(r.height,360),fmin(200,v.height),v.height);
    r.x=clamp(finite_or(r.x,v.x),v.x,v.x+v.width-r.width);
    r.y=clamp(finite_or(r.y,v.y),v.y,v.y+v.height-r.height);
    return r;
}
MWRect MWConstrainExistingRect(MWRect r,MWRect viewport) {
    MWRect v=safe_viewport(viewport);
    r.width=clamp(finite_or(r.width,240),1,v.width);
    r.height=clamp(finite_or(r.height,360),1,v.height);
    r.x=clamp(finite_or(r.x,v.x),v.x,v.x+v.width-r.width);
    r.y=clamp(finite_or(r.y,v.y),v.y,v.y+v.height-r.height); return r;
}

MWRect MWWindowRailRect(MWRect bounds,bool maximized) {
    MWRect v=safe_viewport(bounds);
    double height=maximized ? 0 : fmin(MWResizeRailHeight,v.height);
    return (MWRect){v.x,v.y+v.height-height,v.width,height};
}
MWRect MWWindowContentRect(MWRect bounds,double extraTopInset,bool maximized) {
    MWRect v=safe_viewport(bounds);
    if(maximized) return v;
    MWRect rail=MWWindowRailRect(v,false);
    double header=fmin(rail.y-v.y,MWTitleHeight+fmax(0,finite_or(extraTopInset,0)));
    return (MWRect){v.x,v.y+header,v.width,fmax(0,rail.y-v.y-header)};
}

MWWindowModel MWWindowCreate(MWRect frame) {
    MWWindowModel m={.state=MWWindowLoading,.frame=frame,.restoreFrame=frame,.maximized=false,
        .aspectRatio=frame.width/fmax(1,frame.height-MWWindowChromeHeight),.resizeMode=MWResizeFree,.restoreResizeMode=MWResizeFree,
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
            (m->resizeMode==MWResizeProportional ? MWFitAspectRect(m->restoreFrame,viewport,m->aspectRatio) : MWConstrainExistingRect(m->restoreFrame,viewport));
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
    else m->frame=m->resizeMode==MWResizeProportional ? MWFitAspectRect(m->frame,viewport,m->aspectRatio) : MWConstrainExistingRect(m->frame,viewport);
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
    if(!isfinite(x)||!isfinite(y)||!isfinite(width)||!isfinite(height)||width<=0||height<=0||
       x<0||y<0||x>width||y>height) return false;
    double dx=width-x,dy=top ? y : height-y,radius=fmin(width,height);
    return dx*dx+dy*dy<=radius*radius;
}
MWRect MWUnpinFrame(MWRect frame,double extraTopInset) {
    double inset=clamp(finite_or(extraTopInset,0),0,fmax(0,frame.height-MWWindowChromeHeight-1));
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
bool MWResizeDragActivated(double dx,double dy) {
    return isfinite(dx) && isfinite(dy) && hypot(dx,dy)>=14;
}
MWRect MWProportionalViewport(MWRect viewport,double safeTop) {
    MWRect v=safe_viewport(viewport);
    double inset=clamp(finite_or(safeTop,0),0,fmax(0,v.height-MWWindowChromeHeight-1));
    v.y+=inset; v.height-=inset; return v;
}
MWRect MWBeginProportionalResize(MWRect start,MWRect viewport,double ratio,double safeTop) {
    MWRect v=MWProportionalViewport(viewport,safeTop); ratio=safe_ratio(ratio);
    // Enter aspect mode inside the old footprint, never grow a wide halfscreen
    // window to full height just to retain its width.
    double left=clamp(finite_or(start.x,v.x),v.x,v.x+v.width);
    double top=clamp(finite_or(start.y,v.y),v.y,v.y+v.height);
    double right=clamp(finite_or(start.x+start.width,v.x+v.width),left,v.x+v.width);
    double bottom=clamp(finite_or(start.y+start.height,v.y+v.height),top,v.y+v.height);
    if(right-left<1 || bottom-top<=MWWindowChromeHeight+1) return MWFitAspectRect(start,v,ratio);
    double width=fmin(right-left,(bottom-top-MWWindowChromeHeight)*ratio),height=width/ratio+MWWindowChromeHeight;
    return (MWRect){left+(right-left-width)/2,top+(bottom-top-height)/2,width,height};
}
MWRect MWResizeAspectCornerRect(MWRect start,double dx,double dy,MWRect viewport,double ratio,bool topLeft) {
    MWRect v=safe_viewport(viewport); ratio=safe_ratio(ratio);
    if(v.height<=MWWindowChromeHeight+1) return v;
    start=MWFitAspectRect(start,v,ratio);
    double anchorX=topLeft ? start.x+start.width : start.x;
    double anchorY=topLeft ? start.y+start.height : start.y;
    double maxWidth=topLeft ? anchorX-v.x : v.x+v.width-anchorX;
    double maxHeight=topLeft ? anchorY-v.y : v.y+v.height-anchorY;
    double maximum=fmax(0,fmin(maxWidth,(maxHeight-MWWindowChromeHeight)*ratio));
    double content=fmax(1,start.height-MWWindowChromeHeight),sign=topLeft ? -1 : 1;
    double scale=1+sign*(finite_or(dx,0)*start.width+finite_or(dy,0)*content)/(start.width*start.width+content*content);
    double minimum=fmin(maximum,fmin(start.width,fmax(120,(120-MWWindowChromeHeight)*ratio)));
    double width=clamp(start.width*scale,minimum,maximum),height=width/ratio+MWWindowChromeHeight;
    return (MWRect){topLeft ? anchorX-width : anchorX,topLeft ? anchorY-height : anchorY,width,height};
}
MWRect MWResizeFreeCornerRect(MWRect start,double dx,double dy,MWRect viewport,bool bottomLeft) {
    MWRect v=safe_viewport(viewport);
    start.width=clamp(finite_or(start.width,240),1,v.width);
    start.height=clamp(finite_or(start.height,360),1,v.height);
    start.x=clamp(finite_or(start.x,v.x),v.x,v.x+v.width-start.width);
    start.y=clamp(finite_or(start.y,v.y),v.y,v.y+v.height-start.height);
    double right=start.x+start.width,bottom=start.y+start.height;
    double maxWidth=bottomLeft ? right-v.x : v.x+v.width-start.x;
    double maxHeight=bottomLeft ? v.y+v.height-start.y : bottom-v.y;
    start.width=clamp(start.width+(bottomLeft ? -1 : 1)*finite_or(dx,0),fmin(start.width,fmin(120,maxWidth)),maxWidth);
    start.height=clamp(start.height+(bottomLeft ? 1 : -1)*finite_or(dy,0),fmin(start.height,fmin(120,maxHeight)),maxHeight);
    if(bottomLeft) start.x=right-start.width; else start.y=bottom-start.height;
    return start;
}
MWWindowControls MWWindowControlRects(MWRect bounds,double titleInset,double leadingInset,double trailingInset) {
    MWRect b=safe_viewport(bounds),rail=MWWindowRailRect(b,false);
    double leading=clamp(finite_or(leadingInset,0),0,fmax(0,b.width-1));
    double trailing=clamp(finite_or(trailingInset,0),0,fmax(0,b.width-leading-1));
    double width=b.width-leading-trailing,left=b.x+leading;
    double top=b.y+clamp(finite_or(titleInset,0),0,fmax(0,rail.y-b.y-MWTitleHeight));
    double height=fmin(MWTitleHeight,rail.y-top),corner=fmin(MWCornerTouchSize,width/6);
    double gap=fmin(2,width/20);
    double button=fmin(28,(width-2*corner-5*gap)/4),buttonX=left+(width-4*button-3*gap)/2;
    MWWindowControls c={.topLeft={left,top,corner,height},.topRight={left+width-corner,top,corner,height},
        .bottomLeft={rail.x,rail.y,rail.width/2,rail.height},
        .bottomRight={rail.x+rail.width/2,rail.y,rail.width/2,rail.height}};
    for(unsigned i=0;i<4;i++) c.buttons[i]=(MWRect){buttonX+i*(button+gap),top,button,height};
    return c;
}
MWRect MWKeepShortTitleReachable(MWRect frame,MWRect viewport,double safeTop) {
    MWRect v=safe_viewport(viewport);
    double top=v.y+clamp(finite_or(safeTop,0),0,fmax(0,v.height-MWWindowChromeHeight-1));
    double inset=fmax(0,top-frame.y);
    if(inset>0 && frame.height<inset+MWWindowChromeHeight+1) {
        // Keep dimensions/proportion; move only undersized windows that cannot
        // fit their controls below the system top exclusion.
        frame.y=clamp(top,v.y,v.y+fmax(0,v.height-frame.height));
    }
    return frame;
}
MWWindowModel MWWindowRestoreForLaunch(MWWindowModel saved,MWRect viewport) {
    saved.state=MWWindowLoading; MWWindowReflow(&saved,viewport); return saved;
}
bool MWWindowPark(MWWindowModel *m,MWWindowParking *p) {
    if(!m || !p || p->parked || m->state!=MWWindowVisible) return false;
    p->saved=*m; p->parked=true; m->state=MWWindowParked; return true;
}
bool MWWindowUnpark(MWWindowModel *m,MWWindowParking *p,MWRect viewport) {
    if(!m || !p || !p->parked || m->state!=MWWindowParked) return false;
    *m=p->saved; p->parked=false; MWWindowReflow(m,viewport); return true;
}
MWRect MWParkedRect(MWRect viewport,double contentRatio,double sizeFraction,double chosenRatio,unsigned slot,unsigned count) {
    MWRect v=safe_viewport(viewport);
    count=count<1 ? 1 : (count>4 ? 4 : count); if(slot>=count) slot=count-1;
    double margin=fmin(8,fmin(v.width,v.height)/(2*(count+1)));
    double side=fmin(v.width,v.height)*clamp(finite_or(sizeFraction,0.36),0.18,0.5);
    double slotHeight=(v.height-margin*(count+1))/count;
    double maxWidth=fmin(side,v.width-2*margin),maxHeight=fmin(side,slotHeight);
    double ratio=safe_ratio(isfinite(chosenRatio) && chosenRatio>0 ? chosenRatio : contentRatio);
    double width=fmin(maxWidth,maxHeight*ratio),height=width/ratio;
    return (MWRect){v.x+v.width-margin-width,v.y+margin+slot*(maxHeight+margin),width,height};
}
MWRect MWFitAspectRect(MWRect r, MWRect viewport, double ratio) {
    MWRect v=safe_viewport(viewport); ratio=safe_ratio(ratio);
    if(v.height<=MWWindowChromeHeight+1) return v; // No positive content height can fit.
    double maximum=fmin(v.width,(v.height-MWWindowChromeHeight)*ratio);
    double desired=finite_or(r.width,220);
    double minimum=fmin(maximum,fmin(fmax(1,desired),fmax(120,(120-MWWindowChromeHeight)*ratio)));
    r.width=clamp(finite_or(r.width,minimum),minimum,maximum);
    r.height=r.width/ratio+MWWindowChromeHeight;
    r.x=clamp(finite_or(r.x,v.x),v.x,v.x+v.width-r.width);
    r.y=clamp(finite_or(r.y,v.y),v.y,v.y+v.height-r.height);
    return r;
}
MWRect MWResizeAspectRect(MWRect start, double dx, double dy, MWRect viewport, double ratio) {
    MWRect v=safe_viewport(viewport); ratio=safe_ratio(ratio);
    if(v.height<=MWWindowChromeHeight+1) return v;
    start=MWFitAspectRect(start,v,ratio);
    double content=fmax(1,start.height-MWWindowChromeHeight);
    double scale=1+(finite_or(dx,0)*start.width+finite_or(dy,0)*content)/(start.width*start.width+content*content);
    double maximum=fmin(v.x+v.width-start.x,(v.y+v.height-start.y-MWWindowChromeHeight)*ratio);
    double minimum=fmin(maximum,fmax(220,(200-MWWindowChromeHeight)*ratio));
    start.width=clamp(start.width*scale,minimum,maximum);
    start.height=start.width/ratio+MWWindowChromeHeight;
    return start;
}
MWRect MWMaximizedAspectRect(MWRect viewport, double ratio) {
    MWRect v=safe_viewport(viewport);
    MWRect r=MWFitAspectRect((MWRect){v.x,v.y,v.width,v.height},v,ratio);
    r.x=v.x+(v.width-r.width)/2; r.y=v.y+(v.height-r.height)/2;
    return r;
}
MWRect MWEdgeHandleRect(MWRect viewport, bool right, double position) {
    return MWEntryRect(viewport,right ? 1 : 0,position);
}
MWRect MWEntryRect(MWRect viewport,double xPosition,double yPosition) {
    MWRect v=safe_viewport(viewport);
    double height=fmin(MWEdgeTouchHeight,v.height),width=fmin(MWEdgeTouchWidth,v.width);
    return (MWRect){v.x+clamp(finite_or(xPosition,1),0,1)*(v.width-width),
        v.y+clamp(finite_or(yPosition,0.35),0,1)*(v.height-height),width,height};
}
MWEntryPlacement MWEntryDrop(MWRect viewport,double x,double y) {
    MWRect v=safe_viewport(viewport),r=MWEntryRect(v,0,0);
    double travelX=v.width-r.width,travelY=v.height-r.height;
    r.x=clamp(finite_or(x,v.x),v.x,v.x+travelX);
    r.y=clamp(finite_or(y,v.y),v.y,v.y+travelY);
    bool right=(r.x-v.x)>=travelX/2;
    double edgeDistance=right ? v.x+travelX-r.x : r.x-v.x;
    bool docked=edgeDistance<=fmin(18,travelX/4);
    if(docked) r.x=right ? v.x+travelX : v.x;
    return (MWEntryPlacement){r,travelX>0 ? (r.x-v.x)/travelX : 0,
        travelY>0 ? (r.y-v.y)/travelY : 0,docked,right};
}
MWRect MWPanelPlacementRect(MWRect viewport,MWRect anchor,double desiredHeight) {
    MWRect v=safe_viewport(viewport);
    double margin=fmin(8,fmin(v.width,v.height)/4),gap=8;
    MWRect area={v.x+margin,v.y+margin,v.width-2*margin,v.height-2*margin};
    // Normal chrome is 130pt; the compact UI uses 102pt and retains a 98pt row.
    double usableHeight=200,minimumWidth=fmin(220,area.width);
    double width=fmin(304,area.width),height=fmin(fmax(228,finite_or(desiredHeight,220)),area.height);
    double left=anchor.x-gap-area.x,right=area.x+area.width-(anchor.x+anchor.width+gap);
    double x,y=clamp(anchor.y+anchor.height/2-height/2,area.y,area.y+area.height-height);
    if(left>=width || right>=width) {
        x=left>=right ? anchor.x-gap-width : anchor.x+anchor.width+gap;
    } else {
        double above=anchor.y-gap-area.y,below=area.y+area.height-(anchor.y+anchor.height+gap);
        x=clamp(anchor.x+anchor.width/2-width/2,area.x,area.x+area.width-width);
        // A free entry in the middle leaves no room for a full-width side
        // panel. Use a shorter scrollable panel above/below when possible.
        if(fmax(above,below)>=usableHeight) {
            height=fmin(height,fmax(above,below));
            y=above>=below ? anchor.y-gap-height : anchor.y+anchor.height+gap;
        } else if(fmax(left,right)>=minimumWidth) {
            // A compact landscape phone may fit neither full-width sides nor
            // a useful vertical panel. Narrow the side instead of hiding rows.
            width=fmin(width,fmax(left,right));
            x=left>=right ? anchor.x-gap-width : anchor.x+anchor.width+gap;
        }
    }
    x=clamp(x,area.x,area.x+area.width-width);
    y=clamp(y,area.y,area.y+area.height-height);
    return (MWRect){x,y,width,height};
}
MWContentTransform MWFitContent(double logicalWidth,double logicalHeight,double availableWidth,double availableHeight) {
    double lw=fmax(1,finite_or(logicalWidth,1)),lh=fmax(1,finite_or(logicalHeight,1));
    double aw=fmax(0,finite_or(availableWidth,0)),ah=fmax(0,finite_or(availableHeight,0));
    double scale=fmin(aw/lw,ah/lh);
    return (MWContentTransform){scale,(aw-lw*scale)/2,(ah-lh*scale)/2};
}
