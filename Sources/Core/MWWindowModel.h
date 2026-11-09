// SPDX-License-Identifier: Apache-2.0
#ifndef MW_WINDOW_MODEL_H
#define MW_WINDOW_MODEL_H
#include <stdbool.h>

typedef struct { double x, y, width, height; } MWRect;
#define MWTitleHeight 48.0
typedef enum { MWWindowLoading, MWWindowVisible, MWWindowMinimized, MWWindowFailed, MWWindowClosed } MWWindowState;
typedef enum { MWEventReady, MWEventFailed, MWEventRetry, MWEventMinimize, MWEventRestore, MWEventClose } MWWindowEvent;
typedef enum { MWResizeFree, MWResizeProportional } MWResizeMode;
typedef enum { MWSnapNone, MWSnapTop, MWSnapBottom, MWSnapLeft, MWSnapRight } MWSnapTarget;
typedef struct {
    MWWindowState state;
    MWRect frame, restoreFrame;
    bool maximized;
    double aspectRatio;
    MWResizeMode resizeMode, restoreResizeMode;
    MWSnapTarget snapTarget, restoreSnapTarget;
} MWWindowModel;

MWWindowModel MWWindowCreate(MWRect frame);
MWRect MWConstrainRect(MWRect rect, MWRect viewport);
bool MWWindowApply(MWWindowModel *model, MWWindowEvent event);
bool MWWindowToggleMaximize(MWWindowModel *model, MWRect viewport);
void MWWindowReflow(MWWindowModel *model, MWRect viewport);
MWRect MWFitAspectRect(MWRect rect, MWRect viewport, double ratio);
MWRect MWResizeAspectRect(MWRect start, double dx, double dy, MWRect viewport, double ratio);
MWRect MWResizeFreeRect(MWRect start, double dx, double dy, MWRect viewport, bool leftHandle);
MWRect MWResizeTopRightRect(MWRect start, double dx, double dy, MWRect viewport);
MWRect MWMoveRect(MWRect start, double dx, double dy, MWRect viewport);
MWRect MWSystemCanvas(double screenWidth, double screenHeight, bool landscape);
bool MWCornerHit(double x, double y, double width, double height, bool top);
MWRect MWUnpinFrame(MWRect frame, double extraTopInset);
MWRect MWHalfScreenRect(MWRect viewport, MWSnapTarget target);
MWSnapTarget MWSnapTargetAtPoint(MWRect viewport, double x, double y);
MWSnapTarget MWSnapTargetForDrag(MWRect viewport, MWRect start, MWRect proposed);
MWSnapTarget MWReorientedSnapTarget(MWRect viewport, MWSnapTarget target);
bool MWWindowSnap(MWWindowModel *model, MWSnapTarget target, MWRect viewport);
MWRect MWMaximizedAspectRect(MWRect viewport, double ratio);
MWRect MWEdgeHandleRect(MWRect viewport, bool right, double position);
typedef struct { double scale, x, y; } MWContentTransform;
MWContentTransform MWFitContent(double logicalWidth, double logicalHeight, double availableWidth, double availableHeight);
#endif
