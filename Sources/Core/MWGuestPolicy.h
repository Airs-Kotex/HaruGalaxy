// SPDX-License-Identifier: Apache-2.0
#pragma once
#include "MWWindowModel.h"
typedef struct { bool presented, keepAlive; } MWGuestExecution;
MWGuestExecution MWGuestExecutionForState(MWWindowState state,bool hostVisible,bool keepMinimizedAlive);
// Numeric values are UIDeviceOrientation/UIInterfaceOrientation, kept UIKit-free.
int MWInterfaceOrientationForDevice(int device,int previous);
int MWDeviceOrientationForInterface(int orientation);
int MWOrientationQuarterTurns(int orientation);
