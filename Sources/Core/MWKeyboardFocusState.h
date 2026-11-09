// SPDX-License-Identifier: Apache-2.0
#pragma once
#include <stdbool.h>
#include <stdint.h>

typedef struct {
    uint64_t owner, generation;
    bool selected, suspended;
} MWKeyboardFocusState;
// Owner 0 is the local app; nonzero values identify registered guest sessions.
uint64_t MWKeyboardFocusSelect(MWKeyboardFocusState *state,uint64_t owner);
bool MWKeyboardFocusCurrent(const MWKeyboardFocusState *state,uint64_t owner,uint64_t generation);
bool MWKeyboardFocusRelease(MWKeyboardFocusState *state,uint64_t owner);
void MWKeyboardFocusSuspend(MWKeyboardFocusState *state,bool suspended);
