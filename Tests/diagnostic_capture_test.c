#include "MWDiagnosticCapture.h"
#include <assert.h>
#include <math.h>
#include <stdio.h>

int main(void) {
    MWDiagnosticCapture s={0};
    assert(!MWDiagnosticCaptureBegin(&s,NAN));
    uint64_t first=MWDiagnosticCaptureBegin(&s,10);
    assert(first && !MWDiagnosticCaptureBegin(&s,11));
    assert(MWDiagnosticCapturePoll(&s,first,10)==MWCaptureSample);
    assert(MWDiagnosticCapturePoll(&s,first,10.1)==MWCaptureWait);
    for(int second=11;second<=30;second++) assert(MWDiagnosticCapturePoll(&s,first,second)==MWCaptureSample);
    assert(s.samples==MWDiagnosticCaptureMaxSamples);
    assert(MWDiagnosticCapturePoll(&s,first,30)==MWCaptureFinish);
    assert(MWDiagnosticCapturePoll(&s,first,31)==MWCaptureIgnore);
    uint64_t next=MWDiagnosticCaptureBegin(&s,40);
    assert(MWDiagnosticCapturePoll(&s,first,41)==MWCaptureIgnore);
    // Suspension must not cause a burst of missed samples upon resumption.
    assert(MWDiagnosticCapturePoll(&s,next,59)==MWCaptureSample);
    assert(MWDiagnosticCapturePoll(&s,next,59.1)==MWCaptureWait);
    assert(MWDiagnosticCapturePoll(&s,next,61)==MWCaptureFinish);
    next=MWDiagnosticCaptureBegin(&s,70);
    MWDiagnosticCaptureCancel(&s);
    assert(MWDiagnosticCapturePoll(&s,next,71)==MWCaptureIgnore);
    next=MWDiagnosticCaptureBegin(&s,80);
    assert(MWDiagnosticCapturePoll(&s,next,NAN)==MWCaptureFinish);
    puts("PASS: diagnostic capture is bounded, skips missed samples and rejects stale/cancelled timers");
    return 0;
}
