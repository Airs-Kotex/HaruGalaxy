// SPDX-License-Identifier: Apache-2.0
#pragma once
#include <stdbool.h>
#include <stdint.h>

typedef enum { MWNativeIdle, MWNativeWaiting, MWNativeDeactivated, MWNativeReleasing, MWNativeFinished } MWNativePhase;
typedef enum { MWNativeIgnore, MWNativeWait, MWNativeRelease, MWNativeOpen, MWNativeAbort } MWNativeAction;
typedef struct { uint64_t generation; MWNativePhase phase; double deadline; } MWNativeHandoff;
uint64_t MWNativeHandoffBegin(MWNativeHandoff *state,double now);
bool MWNativeHandoffDeactivated(MWNativeHandoff *state,uint64_t generation);
MWNativeAction MWNativeHandoffObserve(MWNativeHandoff *state,uint64_t generation,double now);
MWNativeAction MWNativeHandoffReleased(MWNativeHandoff *state,uint64_t generation,bool released);
void MWNativeHandoffCancel(MWNativeHandoff *state);
