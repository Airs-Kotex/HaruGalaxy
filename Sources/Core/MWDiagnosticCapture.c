// SPDX-License-Identifier: Apache-2.0
#include "MWDiagnosticCapture.h"
#include <math.h>

uint64_t MWDiagnosticCaptureBegin(MWDiagnosticCapture *s,double now) {
    if(!s || s->active || !isfinite(now)) return 0;
    s->generation++; s->active=true; s->samples=0;
    s->deadline=now+MWDiagnosticCaptureSeconds; s->nextSample=now;
    return s->generation;
}
MWCaptureAction MWDiagnosticCapturePoll(MWDiagnosticCapture *s,uint64_t generation,double now) {
    if(!s || !s->active || generation!=s->generation) return MWCaptureIgnore;
    if(!isfinite(now) || now>s->deadline || s->samples>=MWDiagnosticCaptureMaxSamples) {
        s->active=false; return MWCaptureFinish;
    }
    if(now<s->nextSample) return MWCaptureWait;
    s->nextSample=now+1; s->samples++; return MWCaptureSample;
}
void MWDiagnosticCaptureCancel(MWDiagnosticCapture *s) {
    if(!s) return;
    s->generation++; s->active=false;
}
