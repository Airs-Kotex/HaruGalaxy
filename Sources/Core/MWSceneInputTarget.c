// SPDX-License-Identifier: Apache-2.0
#include "MWSceneInputTarget.h"
#include <string.h>

bool MWSceneInputTargetMatches(int pid,const char *environment,int ownedPID,const char *ownedEnvironment) {
    return pid>0 && pid==ownedPID && environment && ownedEnvironment && *ownedEnvironment &&
        strcmp(environment,ownedEnvironment)==0;
}
