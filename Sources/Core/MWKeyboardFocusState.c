// SPDX-License-Identifier: Apache-2.0
#include "MWKeyboardFocusState.h"
bool MWKeyboardCanPrepareHosting(bool addPID,bool removePID,bool prepare,bool finish) {
    return addPID && removePID && prepare && finish;
}
uint64_t MWKeyboardFocusSelect(MWKeyboardFocusState *s,uint64_t owner) {
    if(!s || s->suspended) return 0;
    s->owner=owner; s->selected=true; return ++s->generation;
}
bool MWKeyboardFocusCurrent(const MWKeyboardFocusState *s,uint64_t owner,uint64_t generation) {
    return s && s->selected && !s->suspended && s->owner==owner && s->generation==generation;
}
bool MWKeyboardFocusRelease(MWKeyboardFocusState *s,uint64_t owner) {
    if(!s || !s->selected || s->owner!=owner) return false;
    s->selected=false; s->generation++; return true;
}
void MWKeyboardFocusSuspend(MWKeyboardFocusState *s,bool suspended) {
    if(!s || s->suspended==suspended) return;
    s->suspended=suspended;
    if(suspended) { s->selected=false; s->generation++; }
}
