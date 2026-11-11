// SPDX-License-Identifier: Apache-2.0
#include "MWSceneGeometry.h"
#include <assert.h>
#include <math.h>
#include <stdio.h>
static void near(double a,double b) { assert(fabs(a-b)<0.00001); }
static void size_is(MWRect r,double w,double h) { near(r.width,w); near(r.height,h); }
static void session_canvas_startup(void) {
    const MWRect contents[]={{0,0,340,424},{0,0,424,340}};
    // [viewport shape][workspace axes][guest axes], including a viewport that
    // already has the correct axes before resolving a constrained guest.
    const double widths[2][2][2]={{{340,424},{340,340}},{{424,424},{340,424}}};
    const double heights[2][2][2]={{{424,340},{424,424}},{{340,340},{424,340}}};
    for(unsigned shape=0;shape<2;shape++) for(int workspace=1;workspace<=4;workspace++)
        for(int guest=1;guest<=4;guest++) for(int proportional=0;proportional<=1;proportional++) {
            MWGuestCanvasState state={0};
            MWRect system=MWSystemCanvas(768,1024,workspace>=3);
            // Workspace layout, focus and start can all lay out before creating
            // the session. Repeating those previews must leave no saved axes.
            for(int preview=0;preview<3;preview++) {
                (void)MWGuestCanvasUpdate(&state,contents[shape],system,workspace,workspace,proportional,false);
                assert(state.orientation==0);
                size_is(state.windowCanvas,0,0);
            }
            system=MWSystemCanvas(768,1024,guest>=3);
            MWRect actual=MWGuestCanvasUpdate(&state,contents[shape],system,workspace,guest,proportional,true);
            double w=proportional ? system.width : widths[shape][workspace>=3][guest>=3];
            double h=proportional ? system.height : heights[shape][workspace>=3][guest>=3];
            size_is(actual,w,h); size_is(state.windowCanvas,w,h);
            assert(state.orientation==guest);
            // Subsequent resize frames and a different handle keep the canvas.
            MWRect resized={0,0,120,84};
            size_is(MWGuestCanvasUpdate(&state,resized,system,workspace,guest,!proportional,true),w,h);
            // A failed session's temporary workspace preview cannot rotate the
            // saved canvas; retry with the same guest must preserve its layout.
            (void)MWGuestCanvasUpdate(&state,resized,system,workspace,workspace,proportional,false);
            size_is(state.windowCanvas,w,h); assert(state.orientation==guest);
            size_is(MWGuestCanvasUpdate(&state,resized,system,workspace,guest,proportional,true),w,h);
            // Established sessions still rotate exactly once on a real axis
            // change. Repeated layouts and a180-degree turn do not swap again.
            int rotated=guest>=3 ? 1 : 3,opposite=guest>=3 ? 2 : 4;
            system=MWSystemCanvas(768,1024,rotated>=3);
            size_is(MWGuestCanvasUpdate(&state,resized,system,workspace,rotated,proportional,true),h,w);
            size_is(MWGuestCanvasUpdate(&state,resized,system,workspace,rotated,proportional,true),h,w);
            size_is(MWGuestCanvasUpdate(&state,resized,system,workspace,opposite,proportional,true),h,w);
        }
    // Concrete review reproduction: iPad landscape host / portrait-only App.
    MWGuestCanvasState portrait={0};
    (void)MWGuestCanvasUpdate(&portrait,contents[0],(MWRect){0,0,1024,768},3,3,false,false);
    MWRect canvas=MWGuestCanvasUpdate(&portrait,contents[0],(MWRect){0,0,768,1024},3,1,false,true);
    size_is(canvas,340,424);
    MWContentTransform fit=MWFitContent(canvas.width,canvas.height,340,424);
    near(fit.scale,1); near(fit.x,0); near(fit.y,0);
    // Startup while maximized: initialize from the RAW restore viewport, orient
    // it for the declared guest, and do not overwrite it with the full viewport.
    MWGuestCanvasState maximized={0};
    MWRect system={0,0,768,1024},full={0,0,1024,768};
    canvas=MWGuestCanvasUpdate(&maximized,contents[1],system,3,1,false,true);
    size_is(canvas,340,424);
    size_is(MWGuestCanvas(MWGuestCanvasForOrientation(full,3,1),canvas,system,true,false),768,1024);
    size_is(MWGuestCanvas(contents[1],maximized.windowCanvas,system,false,false),340,424);
    size_is(MWGuestCanvas(contents[1],maximized.windowCanvas,system,false,true),768,1024);
    // Unknown orientation must remain provisional, even with a session object.
    MWGuestCanvasState unknown={0};
    (void)MWGuestCanvasUpdate(&unknown,contents[0],system,0,0,false,true);
    assert(unknown.orientation==0); size_is(unknown.windowCanvas,0,0);
    size_is(MWGuestCanvasUpdate(&unknown,contents[0],system,3,1,false,true),340,424);
}
int main(void) {
    session_canvas_startup();
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
    puts("PASS: provisional/resolved canvas startup, retry/maximize/rotation, native scene axes, presenter transforms and gravity");
}
