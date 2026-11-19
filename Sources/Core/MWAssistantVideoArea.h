// SPDX-License-Identifier: Apache-2.0
// InterviewOpus compatibility build, 2026-11-18.
#pragma once
#include "MWWindowModel.h"
#include <math.h>
#include <string.h>

static inline bool MWIsInterviewAssistant(const char *bundle) {
    return bundle && (!strcmp(bundle, "com.saasau.interviewopus") ||
                      !strcmp(bundle, "com.saasau.interviewopus.standard"));
}

// The opening has no guest view in it. Even a fully opaque remote surface
// cannot cover it. The remaining rectangle still contains the entire guest.
static inline MWRect MWAssistantContentRect(MWRect full) {
    if (full.width > full.height && full.width >= 400 && full.height >= 180) {
        full.width -= floor(fmin(full.width * .28, full.width - 300));
    } else if (full.height >= 360 && full.width >= 180) {
        double videoHeight = floor(fmin(full.height * .25, full.height - 300));
        full.y += videoHeight;
        full.height -= videoHeight;
    }
    return full;
}
