// SPDX-License-Identifier: Apache-2.0
#pragma once
#include <stdbool.h>
typedef struct { double deadline; bool reportedPending,done; } MWGuestCloseState;
typedef enum { MWGuestCloseIgnore,MWGuestCloseWait,MWGuestCloseReportPending,MWGuestCloseCompleteExit,MWGuestCloseCompleteFailure } MWGuestCloseAction;
void MWGuestCloseBegin(MWGuestCloseState *state,double now);
bool MWGuestCloseDone(const MWGuestCloseState *state);
MWGuestCloseAction MWGuestCloseObserve(MWGuestCloseState *state,double now,bool exited);
MWGuestCloseAction MWGuestCloseReject(MWGuestCloseState *state);
bool MWGuestProcessAbsent(int probeResult,int probeError);
