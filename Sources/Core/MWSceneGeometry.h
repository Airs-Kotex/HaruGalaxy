// SPDX-License-Identifier: Apache-2.0
#pragma once
#include "MWWindowModel.h"
typedef struct { double a,b,c,d,tx,ty; } MWAffine;
// Legacy FBScene frame uses native (portrait) axes; UI content uses the
// requested interface axes. UIKit supplies the matching presenter rotation.
MWRect MWSceneFrameForInterface(MWRect logical,int orientation);
// A guest constrained to different axes from the workspace needs its own
// oriented canvas; the outer window still keeps the user's chosen geometry.
MWRect MWGuestCanvasForOrientation(MWRect logical,int workspace,int guest);
typedef struct {
    MWRect windowCanvas;
    int orientation;
} MWGuestCanvasState;
// Layout before a session exists is only a preview. Establish the saved canvas
// after resolving the guest's direction; then rotate that canvas on axis changes.
MWRect MWGuestCanvasUpdate(MWGuestCanvasState *state,MWRect initialViewport,MWRect systemCanvas,
    int workspace,int guest,bool proportional,bool sessionEstablished);
// An activated resize adopts its requested layout only on successful release.
// Free uses the final viewport; proportional/original canvas use system size.
// During preview and cancellation keep the saved state unchanged.
void MWGuestCanvasCommitResize(MWGuestCanvasState *state,MWRect finalViewport,MWRect systemCanvas,
    int workspace,int guest,bool proportional,bool compatible);
bool MWInvertPresentation(MWAffine forward,MWAffine *inverse);
bool MWNormalizePresentation(MWAffine forward,double width,double height,double logicalWidth,double logicalHeight,
    MWRect *nativeBounds,MWAffine *parentTransform);
// Returns UIKit's interface enum value, or0 for flat/diagonal/invalid data.
int MWOrientationFromGravity(double x,double y,double z);
