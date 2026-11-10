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
bool MWInvertPresentation(MWAffine forward,MWAffine *inverse);
bool MWNormalizePresentation(MWAffine forward,double width,double height,double logicalWidth,double logicalHeight,
    MWRect *nativeBounds,MWAffine *parentTransform);
// Returns UIKit's interface enum value, or0 for flat/diagonal/invalid data.
int MWOrientationFromGravity(double x,double y,double z);
