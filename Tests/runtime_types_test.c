#include "MWRuntimeTypes.h"
#include <assert.h>
#include <stdio.h>

int main(void) {
    assert(MWObjCTypeMatches("v",'v'));
    assert(MWObjCTypeMatches("Vv",'v')); // oneway void, the rejected device path
    assert(MWObjCTypeMatches("rVv",'v'));
    assert(MWObjCTypeMatches("@",'@'));
    assert(MWObjCTypeMatches("N@",'@'));
    assert(MWObjCTypeMatches("@?",'@'));
    assert(!MWObjCTypeMatches("B",'v'));
    assert(!MWObjCTypeMatches("V@",'v'));
    assert(!MWObjCTypeMatches("^v",'v'));
    assert(!MWObjCTypeMatches("V",'v'));
    assert(!MWObjCTypeMatches("",'v'));
    assert(!MWObjCTypeMatches(NULL,'v'));
    puts("PASS: Objective-C oneway/qualified ABI checks and rejected incompatible types");
}
