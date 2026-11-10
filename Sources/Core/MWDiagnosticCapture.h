// SPDX-License-Identifier: Apache-2.0
#pragma once
#include <stdbool.h>
#include <stdint.h>

#define MWDiagnosticCaptureSeconds 20.0
#define MWDiagnosticCaptureMaxSamples 21
typedef struct { uint64_t generation; double deadline,nextSample; unsigned samples; bool active; } MWDiagnosticCapture;
typedef enum { MWCaptureIgnore, MWCaptureWait, MWCaptureSample, MWCaptureFinish } MWCaptureAction;
uint64_t MWDiagnosticCaptureBegin(MWDiagnosticCapture *state,double now);
MWCaptureAction MWDiagnosticCapturePoll(MWDiagnosticCapture *state,uint64_t generation,double now);
void MWDiagnosticCaptureCancel(MWDiagnosticCapture *state);
