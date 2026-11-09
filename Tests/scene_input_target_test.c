// SPDX-License-Identifier: Apache-2.0
#include "MWSceneInputTarget.h"
#include <assert.h>
#include <stdio.h>

int main(void) {
    const char *owned="UIScene:registered-guest-token";
    assert(MWSceneInputTargetMatches(42,owned,42,owned));
    assert(!MWSceneInputTargetMatches(43,owned,42,owned));
    assert(!MWSceneInputTargetMatches(42,"UIScene:registered-guest-token-suffix",42,owned));
    assert(!MWSceneInputTargetMatches(42,"prefix-UIScene:registered-guest-token",42,owned));
    assert(!MWSceneInputTargetMatches(42,"UIScene:other",42,owned));
    assert(!MWSceneInputTargetMatches(42,owned,42,"UIScene:registered"));
    assert(!MWSceneInputTargetMatches(0,owned,0,owned));
    assert(!MWSceneInputTargetMatches(42,NULL,42,owned));
    assert(!MWSceneInputTargetMatches(42,owned,42,NULL));
    assert(!MWSceneInputTargetMatches(42,"",42,""));
    puts("PASS: input target exact PID/environment match; unrelated, prefix and invalid targets pass through");
}
