// SPDX-License-Identifier: Apache-2.0
#ifndef MW_WINDOW_MODEL_H
#define MW_WINDOW_MODEL_H
#include <stdbool.h>

typedef struct { double x, y, width, height; } MWRect;
#define MWTitleHeight 28.0
#define MWResizeRailHeight 8.0
#define MWWindowChromeHeight (MWTitleHeight + MWResizeRailHeight)
#define MWEdgeTouchWidth 56.0
#define MWEdgeTouchHeight 76.0
#define MWCornerTouchSize 28.0
typedef enum { MWWindowLoading, MWWindowVisible, MWWindowMinimized, MWWindowFailed, MWWindowClosed, MWWindowParked } MWWindowState;
typedef enum { MWEventReady, MWEventFailed, MWEventRetry, MWEventMinimize, MWEventRestore, MWEventClose } MWWindowEvent;
typedef enum { MWResizeFree, MWResizeProportional } MWResizeMode;
typedef enum { MWResizeTopLeft, MWResizeTopRight, MWResizeBottomLeft, MWResizeBottomRight } MWResizeCorner;
typedef enum { MWSnapNone, MWSnapTop, MWSnapBottom, MWSnapLeft, MWSnapRight } MWSnapTarget;
typedef struct {
    MWWindowState state;
    MWRect frame, restoreFrame;
    bool maximized;
    double aspectRatio;
    MWResizeMode resizeMode, restoreResizeMode;
    MWSnapTarget snapTarget, restoreSnapTarget;
} MWWindowModel;
typedef struct { bool parked; MWWindowModel saved; } MWWindowParking;

MWWindowModel MWWindowCreate(MWRect frame);
MWRect MWConstrainRect(MWRect rect, MWRect viewport);
MWRect MWConstrainExistingRect(MWRect rect,MWRect viewport);
MWRect MWWindowContentRect(MWRect bounds,double extraTopInset,bool maximized);
MWRect MWWindowRailRect(MWRect bounds,bool maximized);
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
MWRect MWEntryRect(MWRect viewport,double xPosition,double yPosition);
typedef struct { MWRect frame; double xPosition,yPosition; bool docked,right; } MWEntryPlacement;
MWEntryPlacement MWEntryDrop(MWRect viewport,double x,double y);
MWRect MWPanelPlacementRect(MWRect viewport,MWRect anchor,double desiredHeight);
typedef struct { double scale, x, y; } MWContentTransform;
MWContentTransform MWFitContent(double logicalWidth, double logicalHeight, double availableWidth, double availableHeight);
typedef struct { double top,left,bottom,right; } MWInsets;
MWInsets MWGuestSafeInsets(MWRect rendered,MWRect safeRect,double logicalWidth,double logicalHeight);
// Resize previews scale the saved canvas. Snap/maximize use the viewport;
// successful resize release updates windowCanvas separately for the chosen mode.
MWRect MWGuestCanvas(MWRect available,MWRect windowCanvas,MWRect systemCanvas,bool viewportLayout,bool compatible);
bool MWResizeDragActivated(double dx,double dy);
MWRect MWProportionalViewport(MWRect viewport,double safeTop);
MWRect MWBeginProportionalResize(MWRect start,MWRect viewport,double ratio,double safeTop);
MWRect MWResizeAspectCornerRect(MWRect start,double dx,double dy,MWRect viewport,double ratio,bool topLeft);
MWRect MWResizeFreeCornerRect(MWRect start,double dx,double dy,MWRect viewport,bool bottomLeft);
typedef struct { MWRect topLeft,topRight,bottomLeft,bottomRight,buttons[4]; } MWWindowControls;
MWWindowControls MWWindowControlRects(MWRect bounds,double titleInset,double leadingInset,double trailingInset);
MWRect MWKeepShortTitleReachable(MWRect frame,MWRect viewport,double safeTop);
typedef struct { MWRect frame; double titleInset; } MWWindowTitleLayout;
MWWindowTitleLayout MWWindowTitlePlacement(MWWindowModel model,MWRect viewport,double safeTop);
MWWindowModel MWWindowRestoreForLaunch(MWWindowModel saved,MWRect viewport);
bool MWWindowPark(MWWindowModel *model,MWWindowParking *parking);
bool MWWindowUnpark(MWWindowModel *model,MWWindowParking *parking,MWRect viewport);
MWRect MWParkedRect(MWRect viewport,double contentRatio,double sizeFraction,double chosenRatio,unsigned slot,unsigned count);
#endif
