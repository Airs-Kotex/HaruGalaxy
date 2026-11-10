// SPDX-License-Identifier: Apache-2.0
#pragma once
#include <stdbool.h>
typedef enum { MWGuestResolving,MWGuestResetting,MWGuestRelaunching,MWGuestAttached,MWGuestCancelled,MWGuestLaunchFailed } MWGuestLaunchPhase;
typedef enum { MWGuestLaunchIgnore,MWGuestLaunchReset,MWGuestLaunchRelaunch,MWGuestLaunchAttach,MWGuestLaunchFail } MWGuestLaunchAction;
typedef struct { MWGuestLaunchPhase phase; int originalPID; } MWGuestLaunchGate;
MWGuestLaunchAction MWGuestLaunchResolved(MWGuestLaunchGate *gate,int pid);
MWGuestLaunchAction MWGuestLaunchResetFinished(MWGuestLaunchGate *gate,bool success);
void MWGuestLaunchCancel(MWGuestLaunchGate *gate);
bool MWGuestLaunchAllowsHandoff(const MWGuestLaunchGate *gate,bool resetPending);
