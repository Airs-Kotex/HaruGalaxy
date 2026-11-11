// SPDX-License-Identifier: Apache-2.0
#include "MWSceneGeometry.h"
#include <math.h>
MWRect MWSceneFrameForInterface(MWRect logical,int orientation) {
    if(orientation==3 || orientation==4) {
        double width=logical.width; logical.width=logical.height; logical.height=width;
    }
    return logical;
}
MWRect MWGuestCanvasForOrientation(MWRect logical,int workspace,int guest) {
    if(workspace<1 || workspace>4 || guest<1 || guest>4) return logical;
    bool guestLandscape=guest==3 || guest==4,workspaceLandscape=workspace==3 || workspace==4;
    if(guestLandscape!=workspaceLandscape && (logical.width>logical.height)!=guestLandscape) {
        double width=logical.width; logical.width=logical.height; logical.height=width;
    }
    return logical;
}
MWRect MWGuestCanvasUpdate(MWGuestCanvasState *state,MWRect initialViewport,MWRect systemCanvas,
    int workspace,int guest,bool proportional,bool sessionEstablished) {
    MWRect canvas=state->windowCanvas;
    bool established=state->orientation>=1 && state->orientation<=4 &&
        isfinite(canvas.width) && isfinite(canvas.height) && canvas.width>=1 && canvas.height>=1;
    if(!established) {
        MWRect available=MWGuestCanvasForOrientation(initialViewport,workspace,guest);
        canvas=MWGuestCanvas(available,(MWRect){0},systemCanvas,false,proportional);
    } else if(guest>=1 && guest<=4 && (state->orientation>=3)!=(guest>=3)) {
        double width=canvas.width; canvas.width=canvas.height; canvas.height=width;
    }
    if(sessionEstablished && guest>=1 && guest<=4) {
        state->windowCanvas=canvas; state->orientation=guest;
    }
    return canvas;
}
bool MWInvertPresentation(MWAffine t,MWAffine *inverse) {
    if(!inverse || !isfinite(t.a) || !isfinite(t.b) || !isfinite(t.c) || !isfinite(t.d) || !isfinite(t.tx) || !isfinite(t.ty)) return false;
    double determinant=t.a*t.d-t.b*t.c;
    if(!isfinite(determinant) || fabs(determinant)<0.000001) return false;
    MWAffine r={t.d/determinant,-t.b/determinant,-t.c/determinant,t.a/determinant,0,0};
    r.tx=-r.a*t.tx-r.c*t.ty; r.ty=-r.b*t.tx-r.d*t.ty;
    if(!isfinite(r.tx) || !isfinite(r.ty)) return false;
    *inverse=r; return true;
}
bool MWNormalizePresentation(MWAffine t,double width,double height,double logicalWidth,double logicalHeight,
    MWRect *nativeBounds,MWAffine *parentTransform) {
    MWAffine inverse;
    if(!nativeBounds || !parentTransform || !isfinite(width) || !isfinite(height) || !isfinite(logicalWidth) || !isfinite(logicalHeight) ||
       width<1 || height<1 || logicalWidth<1 || logicalHeight<1 || !MWInvertPresentation(t,&inverse)) return false;
    double minX=t.tx,maxX=t.tx,minY=t.ty,maxY=t.ty;
    for(unsigned corner=1;corner<4;corner++) {
        double x=corner&1 ? width : 0,y=corner&2 ? height : 0;
        double px=t.a*x+t.c*y+t.tx,py=t.b*x+t.d*y+t.ty;
        minX=fmin(minX,px);maxX=fmax(maxX,px);minY=fmin(minY,py);maxY=fmax(maxY,py);
    }
    if(!isfinite(maxX-minX) || !isfinite(maxY-minY)) return false;
    *nativeBounds=(MWRect){minX,minY,maxX-minX,maxY-minY};
    MWContentTransform fit=MWFitContent(width,height,logicalWidth,logicalHeight);
    *parentTransform=(MWAffine){inverse.a*fit.scale,inverse.b*fit.scale,inverse.c*fit.scale,inverse.d*fit.scale,
        (inverse.a*minX+inverse.c*minY+inverse.tx)*fit.scale+fit.x,
        (inverse.b*minX+inverse.d*minY+inverse.ty)*fit.scale+fit.y};
    return true;
}
int MWOrientationFromGravity(double x,double y,double z) {
    if(!isfinite(x) || !isfinite(y) || !isfinite(z) || fabs(z)>.85) return 0;
    double ax=fabs(x),ay=fabs(y);
    if(fmax(ax,ay)<.55 || fabs(ax-ay)<.15) return 0;
    return ax>ay ? (x<0 ? 3 : 4) : (y<0 ? 1 : 2);
}
