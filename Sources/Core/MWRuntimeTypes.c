// SPDX-License-Identifier: Apache-2.0
#include "MWRuntimeTypes.h"
#include <string.h>

bool MWObjCTypeMatches(const char *encoding,char expected) {
    if(!encoding) return false;
    // Objective-C qualifiers: const, in, inout, out, bycopy, byref, oneway.
    while(*encoding && strchr("rnNoORV",*encoding)) encoding++;
    return *encoding && *encoding==expected;
}
