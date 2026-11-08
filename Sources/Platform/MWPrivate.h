// SPDX-License-Identifier: Apache-2.0
// Private declarations are pinned to FrontBoardAppLauncher; see NOTICE.md.
#pragma once
#import <mach/mach.h>
#import "../../ThirdParty/FrontBoardAppLauncher/UIKitPrivate+MultitaskSupport.h"
#import <dlfcn.h>

FOUNDATION_EXPORT void MWLoadPrivateFrameworks(void);
FOUNDATION_EXPORT NSString *MWSceneCapabilityIssue(void);
FOUNDATION_EXPORT NSError *MWError(NSInteger code, NSString *message);

