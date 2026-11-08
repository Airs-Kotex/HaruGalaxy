// SPDX-License-Identifier: Apache-2.0
#ifndef MW_WINDOW_MODEL_H
#define MW_WINDOW_MODEL_H
#include <stdbool.h>

typedef struct { double x, y, width, height; } MWRect;
typedef enum { MWWindowLoading, MWWindowVisible, MWWindowMinimized, MWWindowFailed, MWWindowClosed } MWWindowState;
typedef enum { MWEventReady, MWEventFailed, MWEventRetry, MWEventMinimize, MWEventRestore, MWEventClose } MWWindowEvent;
typedef struct {
    MWWindowState state;
    MWRect frame, restoreFrame;
    bool maximized;
} MWWindowModel;

MWWindowModel MWWindowCreate(MWRect frame);
MWRect MWConstrainRect(MWRect rect, MWRect viewport);
bool MWWindowApply(MWWindowModel *model, MWWindowEvent event);
bool MWWindowToggleMaximize(MWWindowModel *model, MWRect viewport);
void MWWindowReflow(MWWindowModel *model, MWRect viewport);
#endif
