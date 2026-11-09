// SPDX-License-Identifier: Apache-2.0
#include "MWKeyboardFocusState.h"
#include <assert.h>
#include <stdio.h>

int main(void) {
    MWKeyboardFocusState s={0};
    uint64_t first=MWKeyboardFocusSelect(&s,1);
    assert(first && MWKeyboardFocusCurrent(&s,1,first));
    uint64_t second=MWKeyboardFocusSelect(&s,2);
    assert(second!=first && !MWKeyboardFocusCurrent(&s,1,first));
    assert(!MWKeyboardFocusRelease(&s,1));
    assert(MWKeyboardFocusCurrent(&s,2,second));
    uint64_t host=MWKeyboardFocusSelect(&s,0);
    assert(!MWKeyboardFocusCurrent(&s,2,second) && MWKeyboardFocusCurrent(&s,0,host));
    assert(!MWKeyboardFocusRelease(&s,2)); // Closing the old guest must not steal search focus.
    MWKeyboardFocusSuspend(&s,true);
    assert(!MWKeyboardFocusCurrent(&s,0,host));
    assert(MWKeyboardFocusSelect(&s,2)==0);
    MWKeyboardFocusSuspend(&s,false);
    assert(!s.selected); // Unlock does not reopen the keyboard spontaneously.
    uint64_t fresh=MWKeyboardFocusSelect(&s,2);
    assert(fresh && fresh!=second && !MWKeyboardFocusCurrent(&s,2,second));
    assert(MWKeyboardFocusRelease(&s,2));
    assert(!MWKeyboardFocusCurrent(&s,2,fresh));
    assert(!MWKeyboardFocusRelease(&s,2));
    puts("PASS: keyboard guest/host ownership, stale completions, close ordering and lock suspension");
}
