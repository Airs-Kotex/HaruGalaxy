// SPDX-License-Identifier: Apache-2.0
#include "MWSceneGeometry.h"
#include <assert.h>
#include <math.h>
#include <stdio.h>
static void near(double a,double b) { assert(fabs(a-b)<0.00001); }
int main(void) {
    for(int orientation=1;orientation<=4;orientation++) {
        MWRect logical={0,0,1024,768};
        MWRect native=MWSceneFrameForInterface(logical,orientation);
        bool landscape=orientation==3 || orientation==4;
        near(native.width,landscape ? 768 : 1024);
        near(native.height,landscape ? 1024 : 768);
        MWRect back=MWSceneFrameForInterface(native,orientation);
        near(back.width,1024); near(back.height,768);
    }
    MWRect observed=MWSceneFrameForInterface((MWRect){0,0,850.92,547.19},3);
    near(observed.width,547.19); near(observed.height,850.92);
    MWRect constrained=MWGuestCanvasForOrientation((MWRect){0,0,390,844},1,3);
    near(constrained.width,844); near(constrained.height,390);
    MWRect constrainedNative=MWSceneFrameForInterface(constrained,3);
    near(constrainedNative.width,390); near(constrainedNative.height,844);
    constrained=MWGuestCanvasForOrientation((MWRect){0,0,380,260},1,3);
    near(constrained.width,380); near(constrained.height,260);
    constrained=MWGuestCanvasForOrientation((MWRect){0,0,844,390},3,1);
    near(constrained.width,390); near(constrained.height,844);
    constrained=MWGuestCanvasForOrientation((MWRect){0,0,380,260},1,1);
    near(constrained.width,380); near(constrained.height,260); // free resize unchanged
    const MWAffine natives[]={{1,0,0,1,40,70},{0,1,-1,0,768,0},{0,-1,1,0,0,1024},{-1,0,0,-1,1024,768}};
    for(unsigned i=0;i<4;i++) {
        MWAffine inv; assert(MWInvertPresentation(natives[i],&inv));
        MWRect bounds; MWAffine parent;
        assert(MWNormalizePresentation(natives[i],1024,768,512,384,&bounds,&parent));
        for(unsigned corner=0;corner<4;corner++) {
            double x=corner&1 ? 1024 : 0,y=corner&2 ? 768 : 0;
            double sx=natives[i].a*x+natives[i].c*y+natives[i].tx;
            double sy=natives[i].b*x+natives[i].d*y+natives[i].ty;
            near(inv.a*sx+inv.c*sy+inv.tx,x); near(inv.b*sx+inv.d*sy+inv.ty,y);
            assert(sx>=bounds.x && sy>=bounds.y && sx<=bounds.x+bounds.width && sy<=bounds.y+bounds.height);
            // UIView's anchor0 parent mapping applies transform to coordinates
            // relative to bounds.origin. Every admitted corner reaches the
            // logical container, including the landscape right-hand region.
            double px=sx-bounds.x,py=sy-bounds.y;
            near(parent.a*px+parent.c*py+parent.tx,x/2);
            near(parent.b*px+parent.d*py+parent.ty,y/2);
        }
        double px=natives[i].a*900+natives[i].c*384+natives[i].tx;
        double py=natives[i].b*900+natives[i].d*384+natives[i].ty;
        assert(px>=bounds.x && py>=bounds.y && px<bounds.x+bounds.width && py<bounds.y+bounds.height);
    }
    MWAffine inverse;
    assert(!MWInvertPresentation((MWAffine){0,0,0,0,0,0},&inverse));
    assert(!MWInvertPresentation((MWAffine){NAN,0,0,1,0,0},&inverse));
    assert(MWOrientationFromGravity(0,-1,0)==1);
    assert(MWOrientationFromGravity(0,1,0)==2);
    assert(MWOrientationFromGravity(-1,0,0)==3);
    assert(MWOrientationFromGravity(1,0,0)==4);
    assert(MWOrientationFromGravity(0,0,-1)==0);
    assert(MWOrientationFromGravity(.7,.7,0)==0);
    assert(MWOrientationFromGravity(NAN,0,0)==0);
    puts("PASS: native scene axes, four presenter rotations/offsets, inverse touch coordinates and stable gravity directions");
}
