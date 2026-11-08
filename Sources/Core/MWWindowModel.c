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
    MWWindowModel m={MWWindowLoading,frame,frame,false};
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
    if(m->maximized) m->frame=MWConstrainRect(m->restoreFrame,viewport);
    else { m->restoreFrame=m->frame; m->frame=safe_viewport(viewport); }
    m->maximized=!m->maximized;
    return true;
}

void MWWindowReflow(MWWindowModel *m, MWRect viewport) {
    if(!m) return;
    m->frame=m->maximized ? safe_viewport(viewport) : MWConstrainRect(m->frame,viewport);
}
